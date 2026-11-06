-- | Compile closed lambda expressions into graphs of SKI combinators.
module Compiler (
  Reduction (..),
  compile,
  compileWith,
  compileSource,
  compileSourceWith,
  compileSourceWithModules,
  reduce,
  reduceWith,
  reduceSource,
  reduceSourceWith,
  reduceSourceWithModules,
) where

import Compiler.Expand (expandSource)
import Data.List (intercalate, nub)
import qualified Data.Map.Strict as Map
import Data.Maybe (fromMaybe)
import qualified Data.Set as Set
import qualified PureLambda.Abs as Pure
import qualified Ski.Abs as Graph

data Term = Var Pure.Name | S | K | I | App Term Term

data Reduction = BetaEta | BetaOnly | EtaOnly | NoReduction deriving (Eq, Show)

-- | Parse and compile one expression. A pure SKI graph cannot contain free names.
compileSource :: String -> Either String Graph.Graph
compileSource = compileSourceWith BetaEta

compileSourceWith :: Reduction -> String -> Either String Graph.Graph
compileSourceWith reduction =
  compileSourceWithModules reduction Map.empty "<input>"

compileSourceWithModules ::
  Reduction ->
  Map.Map FilePath String ->
  FilePath ->
  String ->
  Either String Graph.Graph
compileSourceWithModules reduction modules path source =
  expandSource modules path source >>= compileWith reduction

-- | Parse and reduce one expression without translating it to SKI.
reduceSource :: String -> Either String Pure.Exp
reduceSource = reduceSourceWith BetaEta

reduceSourceWith :: Reduction -> String -> Either String Pure.Exp
reduceSourceWith reduction =
  reduceSourceWithModules reduction Map.empty "<input>"

reduceSourceWithModules ::
  Reduction ->
  Map.Map FilePath String ->
  FilePath ->
  String ->
  Either String Pure.Exp
reduceSourceWithModules reduction modules path source =
  expandSource modules path source >>= reduceChecked reduction

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

type Environment = [(Pure.Name, Value)]

data Value
  = Closure Pure.Name Pure.Exp Environment (Set.Set Pure.Name)
  | Neutral Pure.Name [Value] (Set.Set Pure.Name)
  | -- The result is a shared thunk; free-name checks inspect the source without forcing it.
    Delayed Pure.Exp Environment Value

reduceWith :: Reduction -> Pure.Exp -> Pure.Exp
reduceWith reduction expression = case reduction of
  BetaEta -> reduceEta (quote reduction (evalValue [] expression))
  BetaOnly -> quote reduction (evalValue [] expression)
  EtaOnly -> reduceEta expression
  NoReduction -> expression

evalValue :: Environment -> Pure.Exp -> Value
evalValue environment expression = case expression of
  Pure.EVar name -> fromMaybe (neutral name) (lookup name environment)
  Pure.EAbs name body ->
    Closure name body environment (capturedNames name body environment)
  Pure.EApp function argument ->
    apply (evalValue environment function) (delay environment argument)

delay :: Environment -> Pure.Exp -> Value
delay environment expression = Delayed expression environment (evalValue environment expression)

force :: Value -> Value
force value = case value of
  Delayed _ _ result -> force result
  _ -> value

apply :: Value -> Value -> Value
apply value argument = case force value of
  Closure name body environment _ -> evalValue ((name, argument) : environment) body
  Neutral name arguments names ->
    Neutral name (argument : arguments) (Set.union names (support argument))
  Delayed{} -> error "apply: unresolved delayed value"

neutral :: Pure.Name -> Value
neutral name = Neutral name [] (Set.singleton name)

support :: Value -> Set.Set Pure.Name
support value = case value of
  Closure _ _ _ names -> names
  Neutral _ _ names -> names
  -- A discarded argument can diverge, so capture checks must not evaluate it.
  Delayed expression environment _ -> freeNames (freeVariables [] expression) environment

capturedNames :: Pure.Name -> Pure.Exp -> Environment -> Set.Set Pure.Name
capturedNames bound body = freeNames (freeVariables [bound] body)

freeNames :: [Pure.Name] -> Environment -> Set.Set Pure.Name
freeNames names environment =
  Set.unions
    [ maybe (Set.singleton name) support (lookup name environment)
    | name <- Set.toList (Set.fromList names)
    ]

quote :: Reduction -> Value -> Pure.Exp
quote reduction value = case force value of
  Closure name body environment names ->
    case etaContract reduction name body of
      Just contracted -> quote reduction (evalValue environment contracted)
      Nothing ->
        let binder =
              if Set.member name names
                then freshName name (allNames body ++ Set.toList names)
                else name
         in Pure.EAbs
              binder
              (quote reduction (evalValue ((name, neutral binder) : environment) body))
  Neutral name arguments _ ->
    foldl Pure.EApp (Pure.EVar name) (map (quote reduction) (reverse arguments))
  Delayed{} -> error "quote: unresolved delayed value"

-- | Reduce to beta-eta normal form, including inside abstractions.
reduce :: Pure.Exp -> Pure.Exp
reduce = reduceWith BetaEta

reduceEta :: Pure.Exp -> Pure.Exp
reduceEta expression = case expression of
  Pure.EVar _ -> expression
  Pure.EAbs name body ->
    case etaContract EtaOnly name body of
      Just contracted -> reduceEta contracted
      Nothing ->
        let normalized = reduceEta body
         in case etaContract EtaOnly name normalized of
              Just contracted -> contracted
              Nothing -> Pure.EAbs name normalized
  Pure.EApp function argument ->
    Pure.EApp (reduceEta function) (reduceEta argument)

etaContract :: Reduction -> Pure.Name -> Pure.Exp -> Maybe Pure.Exp
etaContract reduction name body
  | reduction == BetaOnly || reduction == NoReduction = Nothing
  | otherwise = case body of
      Pure.EApp function (Pure.EVar argument)
        | argument == name && not (occursFree name function) -> Just function
      _ -> Nothing

occursFree :: Pure.Name -> Pure.Exp -> Bool
occursFree target expression = case expression of
  Pure.EVar name -> name == target
  Pure.EApp function argument -> occursFree target function || occursFree target argument
  Pure.EAbs name body -> name /= target && occursFree target body

allNames :: Pure.Exp -> [Pure.Name]
allNames expression = go expression []
 where
  go term rest = case term of
    Pure.EVar name -> name : rest
    Pure.EApp function argument -> go function (go argument rest)
    Pure.EAbs name body -> name : go body rest

freshName :: Pure.Name -> [Pure.Name] -> Pure.Name
freshName (Pure.Name base) used = go (1 :: Int)
 where
  go suffix =
    let candidate = Pure.Name (base ++ "_" ++ show suffix)
     in if candidate `elem` used then go (suffix + 1) else candidate

nameText :: Pure.Name -> String
nameText (Pure.Name name) = name

freeVariables :: [Pure.Name] -> Pure.Exp -> [Pure.Name]
freeVariables bound expression = go bound expression []
 where
  go scope term rest = case term of
    Pure.EVar name
      | name `elem` scope -> rest
      | otherwise -> name : rest
    Pure.EApp function argument -> go scope function (go scope argument rest)
    Pure.EAbs name body -> go (name : scope) body rest

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
