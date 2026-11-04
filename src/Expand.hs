{-# LANGUAGE TemplateHaskell #-}

-- | Expand library definitions into pure lambda calculus.
module Expand (expand) where

import qualified CoreLambda.Abs as Core
import qualified CoreLambda.Par as Core
import qualified CoreLambda.Print as Core
import Data.List (intercalate)
import qualified Data.Map.Strict as Map
import LibrarySource (embeddedSources)
import qualified PureLambda.Abs as Pure
import System.FilePath (dropExtension)

sources :: [(FilePath, String)]
sources = $(embeddedSources)

definitions :: Either String (Map.Map String Core.Exp)
definitions = Map.fromList <$> traverse parseDefinition sources
 where
  parseDefinition (path, source) = do
    expression <- case Core.pExp (Core.myLexer source) of
      Left problem -> Left ("lib/" ++ path ++ ": " ++ problem)
      Right value -> Right value
    let free = freeVariables [] expression
    if null free
      then Right (dropExtension path, expression)
      else Left ("lib/" ++ path ++ ": free variable(s): " ++ intercalate ", " free)

expand :: Core.Exp -> Either String Pure.Exp
expand expression = definitions >>= \library -> go library [] expression

go :: Map.Map String Core.Exp -> [String] -> Core.Exp -> Either String Pure.Exp
go library stack expression = case expression of
  Core.EVar (Core.Name name) -> Right (Pure.EVar (Pure.Name name))
  Core.EApp function argument -> Pure.EApp <$> go library stack function <*> go library stack argument
  Core.EAbs (Core.Name name) body -> Pure.EAbs (Pure.Name name) <$> go library stack body
  builtin ->
    let name = Core.printTree builtin
     in if name `elem` stack
          then
            Left
              ("cyclic library definition: " ++ intercalate " -> " (reverse (name : stack)))
          else case Map.lookup name library of
            Nothing -> Left ("missing library definition: lib/" ++ name ++ ".lambda")
            Just definition -> go library (name : stack) definition

freeVariables :: [String] -> Core.Exp -> [String]
freeVariables bound expression = case expression of
  Core.EVar (Core.Name name)
    | name `elem` bound -> []
    | otherwise -> [name]
  Core.EApp function argument -> freeVariables bound function ++ freeVariables bound argument
  Core.EAbs (Core.Name name) body -> freeVariables (name : bound) body
  _ -> []
