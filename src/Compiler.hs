-- | Compile closed lambda expressions into graphs of SKI combinators.
module Compiler (
  Reduction (..),
  compile,
  compileWith,
  compileSource,
  compileSourceWith,
  reduce,
  reduceWith,
  reduceSource,
  reduceSourceWith,
) where

import qualified CoreLambda.Par as Core
import Data.List (intercalate, nub)
import Expand (expand)
import qualified Graph.Abs as Graph
import qualified PureLambda.Abs as Pure

data Term = Var Pure.Name | S | K | I | App Term Term

data Reduction = BetaEta | BetaOnly | EtaOnly | NoReduction deriving (Eq, Show)

-- | Parse and compile one expression. A pure SKI graph cannot contain free names.
compileSource :: String -> Either String Graph.Graph
compileSource = compileSourceWith BetaEta

compileSourceWith :: Reduction -> String -> Either String Graph.Graph
compileSourceWith reduction source =
  Core.pExp (Core.myLexer source) >>= compileWith reduction . expand

-- | Parse and reduce one expression without translating it to SKI.
reduceSource :: String -> Either String Pure.Exp
reduceSource = reduceSourceWith BetaEta

reduceSourceWith :: Reduction -> String -> Either String Pure.Exp
reduceSourceWith reduction source =
  Core.pExp (Core.myLexer source)
    >>= reduceChecked reduction . expand

compile :: Pure.Exp -> Either String Graph.Graph
compile = compileWith BetaEta

compileWith :: Reduction -> Pure.Exp -> Either String Graph.Graph
compileWith reduction expression = do
  reduced <- reduceChecked reduction expression
  pure (Graph.GGraph (snd (emit 0 (toTerm reduced))))

reduceChecked :: Reduction -> Pure.Exp -> Either String Pure.Exp
reduceChecked reduction expression =
  case nub (freeVariables [] expression) of
    [] -> Right (reduceWith reduction expression)
    names -> Left ("free variable(s): " ++ intercalate ", " (map nameText names))

-- | Reduce to beta-eta normal form, including inside abstractions.
reduce :: Pure.Exp -> Pure.Exp
reduce = reduceWith BetaEta

reduceWith :: Reduction -> Pure.Exp -> Pure.Exp
reduceWith reduction expression = case expression of
  Pure.EVar _ -> expression
  Pure.EAbs name body ->
    case etaContract reduction name body of
      Just contracted -> reduceWith reduction contracted
      Nothing ->
        let normalized = reduceWith reduction body
         in case etaContract reduction name normalized of
              Just contracted -> contracted
              Nothing -> Pure.EAbs name normalized
  Pure.EApp function argument
    | reduction == EtaOnly || reduction == NoReduction ->
        Pure.EApp (reduceWith reduction function) (reduceWith reduction argument)
    | otherwise ->
        case reduceHead function of
          Pure.EAbs name body -> reduceWith reduction (substitute name argument body)
          headForm ->
            Pure.EApp (reduceWith reduction headForm) (reduceWith reduction argument)

etaContract :: Reduction -> Pure.Name -> Pure.Exp -> Maybe Pure.Exp
etaContract reduction name body
  | reduction == BetaOnly || reduction == NoReduction = Nothing
  | otherwise = case body of
      Pure.EApp function (Pure.EVar argument)
        | argument == name && name `notElem` freeVariables [] function -> Just function
      _ -> Nothing

-- Find the next outermost redex without reducing arguments or abstraction bodies.
reduceHead :: Pure.Exp -> Pure.Exp
reduceHead expression = case expression of
  Pure.EApp function argument ->
    case reduceHead function of
      Pure.EAbs name body -> reduceHead (substitute name argument body)
      headForm -> Pure.EApp headForm argument
  _ -> expression

-- Capture-avoiding substitution of an expression for a free variable.
substitute :: Pure.Name -> Pure.Exp -> Pure.Exp -> Pure.Exp
substitute target replacement expression = case expression of
  Pure.EVar name
    | name == target -> replacement
    | otherwise -> expression
  Pure.EApp function argument ->
    Pure.EApp
      (substitute target replacement function)
      (substitute target replacement argument)
  Pure.EAbs name body
    | name == target -> expression
    | target `notElem` freeVariables [] body -> expression
    | name `notElem` freeVariables [] replacement ->
        Pure.EAbs name (substitute target replacement body)
    | otherwise ->
        let fresh = freshName name (allNames body ++ allNames replacement ++ [target])
            renamed = substitute name (Pure.EVar fresh) body
         in Pure.EAbs fresh (substitute target replacement renamed)

allNames :: Pure.Exp -> [Pure.Name]
allNames expression = case expression of
  Pure.EVar name -> [name]
  Pure.EApp function argument -> allNames function ++ allNames argument
  Pure.EAbs name body -> name : allNames body

freshName :: Pure.Name -> [Pure.Name] -> Pure.Name
freshName (Pure.Name base) used = go (1 :: Int)
 where
  go suffix =
    let candidate = Pure.Name (base ++ "_" ++ show suffix)
     in if candidate `elem` used then go (suffix + 1) else candidate

nameText :: Pure.Name -> String
nameText (Pure.Name name) = name

freeVariables :: [Pure.Name] -> Pure.Exp -> [Pure.Name]
freeVariables bound expression = case expression of
  Pure.EVar name
    | name `elem` bound -> []
    | otherwise -> [name]
  Pure.EApp function argument ->
    freeVariables bound function ++ freeVariables bound argument
  Pure.EAbs name body -> freeVariables (name : bound) body

toTerm :: Pure.Exp -> Term
toTerm expression = case expression of
  Pure.EVar name -> Var name
  Pure.EApp function argument -> App (toTerm function) (toTerm argument)
  Pure.EAbs name body -> abstract name (toTerm body)

abstract :: Pure.Name -> Term -> Term
abstract name term
  | not (occurs name term) = App K term
abstract name (Var _) = I
abstract name (App function argument) =
  App (App S (abstract name function)) (abstract name argument)
abstract _ _ = error "abstract: variable occurrence in a combinator"

occurs :: Pure.Name -> Term -> Bool
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
