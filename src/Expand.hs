{-# LANGUAGE TemplateHaskell #-}

-- | Resolve modules and expand library definitions into pure lambda calculus.
module Expand (expand, expandSource) where

import Control.Monad (foldM, when)
import qualified CoreLambda.Abs as Core
import qualified CoreLambda.Print as Core
import Data.List (intercalate)
import qualified Data.Map.Strict as Map
import LibrarySource (embeddedSources)
import ModuleSource (Import (..), Module (..), parseModule)
import qualified PureLambda.Abs as Pure
import System.FilePath (normalise, takeDirectory, (</>))

sources :: Map.Map FilePath String
sources =
  Map.fromList
    [(normalise ("lib" </> path), source) | (path, source) <- $(embeddedSources)]

standardIndex :: Either String (Map.Map String FilePath)
standardIndex = foldM addModule Map.empty (Map.toList sources)
 where
  addModule index (path, source) = do
    parsed <- case parseModule source of
      Left problem -> Left (path ++ ": " ++ problem)
      Right result -> Right result
    foldM (addExport path) index (moduleExports parsed)
  addExport path index name
    | Map.member name index = Left ("duplicate standard library export: " ++ name)
    | otherwise = Right (Map.insert name path index)

-- | Keep the expression API available to callers that already have an AST.
expand :: Core.Exp -> Either String Pure.Exp
expand expression = expandSource Map.empty "<input>" ("@! " ++ Core.printTree expression ++ ";")

-- | Expand a complete source file using embedded and externally loaded modules.
expandSource ::
  Map.Map FilePath String -> FilePath -> String -> Either String Pure.Exp
expandSource external path source = do
  let file = normalise path
      allSources = Map.insert file source (Map.union external sources)
  library <- standardIndex
  parsed <- parseModule source
  body <-
    maybe (Left "module has no final expression") Right (moduleExpression parsed)
  validateImports allSources file parsed
  go library allSources file [] [] body

parsedModule :: Map.Map FilePath String -> FilePath -> Either String Module
parsedModule allSources file = do
  source <-
    maybe (Left ("module not found: " ++ file)) Right (Map.lookup file allSources)
  case parseModule source of
    Left problem -> Left (file ++ ": " ++ problem)
    Right parsed -> Right parsed

validateImports ::
  Map.Map FilePath String -> FilePath -> Module -> Either String ()
validateImports allSources file parsed = do
  let locals = map fst (moduleDefinitions parsed)
      imported = concat [names | Import _ names <- moduleImports parsed]
      conflicts = [name | name <- imported, name `elem` locals]
      duplicates =
        [ name
        | (index, name) <- zip [0 :: Int ..] imported
        , name `elem` take index imported
        ]
  case conflicts ++ duplicates of
    name : _ -> Left (file ++ ": duplicate name: " ++ name)
    [] -> pure ()
  mapM_ checkImport (moduleImports parsed)
 where
  checkImport (Import relative names) = do
    let target = normalise (takeDirectory file </> relative)
    dependency <- parsedModule allSources target
    mapM_ (checkName target dependency) names
  checkName target dependency name
    | name `elem` moduleExports dependency = pure ()
    | otherwise = Left (file ++ ": " ++ target ++ " does not export " ++ name)

resolve ::
  Map.Map String FilePath ->
  Map.Map FilePath String ->
  FilePath ->
  [(FilePath, String)] ->
  String ->
  Either String Pure.Exp
resolve library allSources file stack name = do
  let key = (file, name)
  when (key `elem` stack) $
    Left
      ("cyclic definition: " ++ intercalate " -> " (map snd (reverse (key : stack))))
  parsed <- parsedModule allSources file
  validateImports allSources file parsed
  case lookup name (moduleDefinitions parsed) of
    Just body -> do
      result <- go library allSources file (key : stack) [] body
      case freeVariables [] result of
        [] -> Right result
        names ->
          Left (file ++ ": " ++ name ++ ": free variable(s): " ++ intercalate ", " names)
    Nothing -> Left (file ++ ": undefined name: " ++ name)

go ::
  Map.Map String FilePath ->
  Map.Map FilePath String ->
  FilePath ->
  [(FilePath, String)] ->
  [String] ->
  Core.Exp ->
  Either String Pure.Exp
go library allSources file stack bound expression = case expression of
  Core.EVar (Core.Name name)
    | name `elem` bound -> Right (Pure.EVar (Pure.Name name))
    | otherwise -> do
        definition <- lookupName allSources file name
        case definition of
          Nothing -> Right (Pure.EVar (Pure.Name name))
          Just target -> resolve library allSources target stack name
  Core.EApp function argument ->
    Pure.EApp
      <$> go library allSources file stack bound function
      <*> go library allSources file stack bound argument
  Core.EAbs (Core.Name name) body ->
    Pure.EAbs (Pure.Name name)
      <$> go library allSources file stack (name : bound) body
  Core.EBuiltin (Core.Builtin name) -> do
    imported <- lookupName allSources file name
    case imported of
      Just target -> resolve library allSources target stack name
      Nothing -> do
        target <-
          maybe
            (Left ("standard library does not export " ++ name))
            Right
            (Map.lookup name library)
        resolve library allSources target stack name

lookupName ::
  Map.Map FilePath String -> FilePath -> String -> Either String (Maybe FilePath)
lookupName allSources file name = do
  parsed <- parsedModule allSources file
  validateImports allSources file parsed
  if name `elem` map fst (moduleDefinitions parsed)
    then Right (Just file)
    else case [ normalise (takeDirectory file </> relative)
              | Import relative names <- moduleImports parsed
              , name `elem` names
              ] of
      target : _ -> Right (Just target)
      [] -> Right Nothing

freeVariables :: [String] -> Pure.Exp -> [String]
freeVariables bound expression = case expression of
  Pure.EVar (Pure.Name name)
    | name `elem` bound -> []
    | otherwise -> [name]
  Pure.EApp function argument -> freeVariables bound function ++ freeVariables bound argument
  Pure.EAbs (Pure.Name name) body -> freeVariables (name : bound) body
