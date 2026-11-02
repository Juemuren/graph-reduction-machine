-- | Compile closed lambda expressions into graphs of SKI combinators.
module Compiler (compile, compileSource) where

import Data.List (intercalate, nub)
import Desugar (desugar)
import qualified Graph.Abs as Graph
import qualified Lambda.Abs as Lambda
import qualified Lambda.Par as Lambda

data Term = Var Lambda.Name | S | K | I | App Term Term

-- | Parse and compile one expression. A pure SKI graph cannot contain free names.
compileSource :: String -> Either String Graph.Graph
compileSource source = Lambda.pExp (Lambda.myLexer source) >>= compile

compile :: Lambda.Exp -> Either String Graph.Graph
compile expression =
  case nub (freeVariables [] pureExpression) of
    [] -> Right (Graph.GGraph (snd (emit 0 (toTerm pureExpression))))
    names -> Left ("free variable(s): " ++ intercalate ", " (map nameText names))
  where
    pureExpression = desugar expression

nameText :: Lambda.Name -> String
nameText (Lambda.Name name) = name

freeVariables :: [Lambda.Name] -> Lambda.Exp -> [Lambda.Name]
freeVariables bound expression = case expression of
  Lambda.EVar name | name `elem` bound -> []
                   | otherwise -> [name]
  Lambda.EApp function argument ->
    freeVariables bound function ++ freeVariables bound argument
  Lambda.EAbs name body -> freeVariables (name : bound) body
  _ -> error "freeVariables: arithmetic syntax escaped desugaring"

toTerm :: Lambda.Exp -> Term
toTerm expression = case expression of
  Lambda.EVar name -> Var name
  Lambda.EApp function argument -> App (toTerm function) (toTerm argument)
  Lambda.EAbs name body -> abstract name (toTerm body)
  _ -> error "toTerm: arithmetic syntax escaped desugaring"

abstract :: Lambda.Name -> Term -> Term
abstract name term
  | not (occurs name term) = App K term
abstract name (Var _) = I
abstract name (App function argument) =
  App (App S (abstract name function)) (abstract name argument)
abstract _ _ = error "abstract: variable occurrence in a combinator"

occurs :: Lambda.Name -> Term -> Bool
occurs name term = case term of
  Var other -> name == other
  App function argument -> occurs name function || occurs name argument
  _ -> False

-- Allocate the parent first, so the graph root is #0.
emit :: Int -> Term -> (Int, [Graph.NodeDef])
emit next term = case term of
  S -> (next + 1, [Graph.NS (nodeId next)])
  K -> (next + 1, [Graph.NK (nodeId next)])
  I -> (next + 1, [Graph.NI (nodeId next)])
  App function argument ->
    let (afterFunction, functionNodes) = emit (next + 1) function
        (afterArgument, argumentNodes) = emit afterFunction argument
        parent = Graph.NApp (nodeId next) (nodeId (next + 1)) (nodeId afterFunction)
    in (afterArgument, parent : functionNodes ++ argumentNodes)
  Var _ -> error "emit: free variable escaped validation"

nodeId :: Int -> Graph.NodeId
nodeId number = Graph.NodeId ('#' : show number)
