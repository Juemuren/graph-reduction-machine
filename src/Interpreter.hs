-- | Reduce a parsed SKI graph to normal form while preserving shared nodes.
module Interpreter (
  interpretSource,
  interpret,
  decodeNaturalSource,
  decodeNatural,
  decodeBooleanSource,
  decodeBoolean,
  decodeIntegerSource,
  decodeInteger,
  decodeRationalSource,
  decodeRational,
  decodeRealSource,
  decodeReal,
) where

import Control.Monad (foldM, when)
import Control.Monad.State.Strict (StateT, evalStateT, get, gets, lift, modify)
import qualified Data.IntMap.Strict as IntMap
import qualified Data.Map.Strict as Map
import Data.Ratio ((%))
import qualified Data.Set as Set
import qualified Graph.Abs as Graph
import qualified Graph.Par as Graph
import Numeric.Natural (Natural)

type Address = Int

data Node
  = S
  | K
  | I
  | App Address Address
  | Indirect Address
  | ProbeFunction
  | ProbeValue
  | ChurchNumeral Natural

data Machine = Machine
  { heap :: IntMap.IntMap Node
  , nextAddress :: Address
  , steps :: Int
  , stepLimit :: Int
  }

type Run a = StateT Machine (Either String) a

interpretSource :: Int -> String -> Either String Graph.Graph
interpretSource limit source =
  Graph.pGraph (Graph.myLexer source) >>= interpret limit

interpret :: Int -> Graph.Graph -> Either String Graph.Graph
interpret limit graph = do
  (initialHeap, root) <- loadGraph graph
  let machine = Machine initialHeap (IntMap.size initialHeap) 0 limit
  evalStateT (normalize root >> serialize root) machine

-- | Apply a closed SKI term to symbolic f and x, then recognize f^n x.
decodeNaturalSource :: Int -> String -> Either String (Maybe Natural)
decodeNaturalSource limit source =
  Graph.pGraph (Graph.myLexer source) >>= decodeNatural limit

decodeNatural :: Int -> Graph.Graph -> Either String (Maybe Natural)
decodeNatural limit graph = do
  (initialHeap, root) <- loadGraph graph
  let machine = Machine initialHeap (IntMap.size initialHeap) 0 limit
  evalStateT (decodeNaturalAt root) machine

-- | Decode a Church integer represented by a pair of Church naturals.
decodeIntegerSource :: Int -> String -> Either String (Maybe Integer)
decodeIntegerSource limit source =
  Graph.pGraph (Graph.myLexer source) >>= decodeInteger limit

decodeInteger :: Int -> Graph.Graph -> Either String (Maybe Integer)
decodeInteger limit graph = do
  (initialHeap, root) <- loadGraph graph
  let machine = Machine initialHeap (IntMap.size initialHeap) 0 limit
  evalStateT (decodeIntegerAt root) machine

decodeIntegerAt :: Address -> Run (Maybe Integer)
decodeIntegerAt root = do
  components <- decodePairAt root
  case components of
    Nothing -> pure Nothing
    Just (positive, negative) -> do
      first <- decodeNaturalAt positive
      second <- decodeNaturalAt negative
      pure ((\a b -> toInteger a - toInteger b) <$> first <*> second)

-- | Decode a pair of Church integers as a reduced rational number.
decodeRationalSource :: Int -> String -> Either String (Maybe Rational)
decodeRationalSource limit source =
  Graph.pGraph (Graph.myLexer source) >>= decodeRational limit

decodeRational :: Int -> Graph.Graph -> Either String (Maybe Rational)
decodeRational limit graph = do
  (initialHeap, root) <- loadGraph graph
  let machine = Machine initialHeap (IntMap.size initialHeap) 0 limit
  evalStateT (decodeRationalAt root) machine

decodeRationalAt :: Address -> Run (Maybe Rational)
decodeRationalAt root = do
  components <- decodePairAt root
  case components of
    Nothing -> pure Nothing
    Just (numerator, denominator) -> do
      first <- decodeIntegerAt numerator
      second <- decodeIntegerAt denominator
      pure $ case (first, second) of
        (Just a, Just b) | b /= 0 -> Just (a % b)
        _ -> Nothing

-- | Decode the rational approximation at the given natural index.
decodeRealSource :: Int -> Natural -> String -> Either String (Maybe Rational)
decodeRealSource limit precision source =
  Graph.pGraph (Graph.myLexer source) >>= decodeReal limit precision

decodeReal :: Int -> Natural -> Graph.Graph -> Either String (Maybe Rational)
decodeReal limit precision graph = do
  (initialHeap, root) <- loadGraph graph
  let machine = Machine initialHeap (IntMap.size initialHeap) 0 limit
  evalStateT
    ( do
        index <- allocate (ChurchNumeral precision)
        approximation <- allocate (App root index)
        decodeRationalAt approximation
    )
    machine

decodePairAt :: Address -> Run (Maybe (Address, Address))
decodePairAt root = do
  selector <- allocate ProbeFunction
  selected <- allocate (App root selector)
  whnf selected
  (headNode, applications) <- spine selected
  pure $ case (headNode, applications) of
    (ProbeFunction, [(_, first), (_, second)]) -> Just (first, second)
    _ -> Nothing

decodeNaturalAt :: Address -> Run (Maybe Natural)
decodeNaturalAt root = do
  function <- allocate ProbeFunction
  value <- allocate ProbeValue
  appliedOnce <- allocate (App root function)
  appliedTwice <- allocate (App appliedOnce value)
  normalize appliedTwice
  countApplications function value appliedTwice 0

-- | Apply a closed SKI term to two distinct symbolic values and identify the selected one.
decodeBooleanSource :: Int -> String -> Either String (Maybe Bool)
decodeBooleanSource limit source =
  Graph.pGraph (Graph.myLexer source) >>= decodeBoolean limit

decodeBoolean :: Int -> Graph.Graph -> Either String (Maybe Bool)
decodeBoolean limit graph = do
  (initialHeap, root) <- loadGraph graph
  let machine = Machine initialHeap (IntMap.size initialHeap) 0 limit
  evalStateT
    ( do
        trueValue <- allocate ProbeFunction
        falseValue <- allocate ProbeValue
        appliedOnce <- allocate (App root trueValue)
        appliedTwice <- allocate (App appliedOnce falseValue)
        normalize appliedTwice
        result <- resolve appliedTwice
        pure $
          if result == trueValue
            then Just True
            else if result == falseValue then Just False else Nothing
    )
    machine

countApplications ::
  Address -> Address -> Address -> Natural -> Run (Maybe Natural)
countApplications function value address count = do
  actual <- resolve address
  if actual == value
    then pure (Just count)
    else do
      node <- readNode actual
      case node of
        App headAddress argument -> do
          actualHead <- resolve headAddress
          if actualHead == function
            then countApplications function value argument (count + 1)
            else pure Nothing
        _ -> pure Nothing

loadGraph :: Graph.Graph -> Either String (IntMap.IntMap Node, Address)
loadGraph (Graph.GGraph definitions) = do
  names <- foldM addDefinition Map.empty definitions
  root <- maybe (Left "missing root node #0") Right (Map.lookup "#0" names)
  let addresses = Map.fromList (zip (Map.keys names) [0 ..])
      definitionsByAddress =
        [ (addresses Map.! name, definition)
        | (name, definition) <- Map.toList names
        ]
  nodes <- traverse (resolveDefinition addresses) definitionsByAddress
  let initialHeap = IntMap.fromList nodes
      rootAddress = addresses Map.! "#0"
  checkAcyclic initialHeap rootAddress
  pure (initialHeap, rootAddress)
 where
  addDefinition table definition =
    let name = definitionName definition
     in if Map.member name table
          then Left ("duplicate node " ++ name)
          else Right (Map.insert name definition table)

  resolveDefinition addresses (address, definition) = do
    node <- case definition of
      Graph.NS _ -> Right S
      Graph.NK _ -> Right K
      Graph.NI _ -> Right I
      Graph.NApp _ function argument ->
        App <$> findReference addresses function <*> findReference addresses argument
    pure (address, node)

  findReference addresses (Graph.NodeId name) =
    maybe (Left ("undefined node " ++ name)) Right (Map.lookup name addresses)

definitionName :: Graph.NodeDef -> String
definitionName definition = case definition of
  Graph.NS node -> name node
  Graph.NK node -> name node
  Graph.NI node -> name node
  Graph.NApp node _ _ -> name node
 where
  name (Graph.NodeId value) = value

checkAcyclic :: IntMap.IntMap Node -> Address -> Either String ()
checkAcyclic nodes root = do
  _ <- visit Set.empty Set.empty root
  pure ()
 where
  visit active done address
    | Set.member address active = Left "cycle reachable from #0"
    | Set.member address done = Right done
    | otherwise = case nodes IntMap.! address of
        App function argument -> do
          let active' = Set.insert address active
          done' <- visit active' done function
          done'' <- visit active' done' argument
          Right (Set.insert address done'')
        _ -> Right (Set.insert address done)

resolve :: Address -> Run Address
resolve address = do
  node <- gets ((IntMap.! address) . heap)
  case node of
    Indirect target -> resolve target
    _ -> pure address

readNode :: Address -> Run Node
readNode address = do
  actual <- resolve address
  gets ((IntMap.! actual) . heap)

writeNode :: Address -> Node -> Run ()
writeNode address node =
  modify
    (\machine -> machine{heap = IntMap.insert address node (heap machine)})

allocate :: Node -> Run Address
allocate node = do
  address <- gets nextAddress
  modify
    ( \machine ->
        machine
          { heap = IntMap.insert address node (heap machine)
          , nextAddress = address + 1
          }
    )
  pure address

-- Applications and arguments are ordered from the head outwards.
spine :: Address -> Run (Node, [(Address, Address)])
spine address = go address []
 where
  go current applications = do
    actual <- resolve current
    node <- readNode actual
    case node of
      App function argument -> go function ((actual, argument) : applications)
      _ -> pure (node, applications)

whnf :: Address -> Run ()
whnf address = do
  (headNode, applications) <- spine address
  let arity = case headNode of
        I -> 1
        K -> 2
        S -> 3
        ChurchNumeral _ -> 2
        _ -> 0
  if length applications < arity || arity == 0
    then pure ()
    else do
      machine <- get
      when (steps machine >= stepLimit machine) $
        lift (Left ("reduction exceeded step limit " ++ show (stepLimit machine)))
      let (redex, _) = applications !! (arity - 1)
          arguments = map snd (take arity applications)
      case (headNode, arguments) of
        (I, [x]) -> writeNode redex (Indirect x)
        (K, [x, _]) -> writeNode redex (Indirect x)
        (S, [x, y, z]) -> do
          left <- allocate (App x z)
          right <- allocate (App y z)
          writeNode redex (App left right)
        (ChurchNumeral count, [function, value]) -> do
          when (count >= fromIntegral (stepLimit machine - steps machine)) $
            lift (Left ("reduction exceeded step limit " ++ show (stepLimit machine)))
          result <-
            foldM (\argument _ -> allocate (App function argument)) value [1 .. count]
          writeNode redex (Indirect result)
          modify (\state -> state{steps = steps state + fromIntegral count})
        _ -> lift (Left "internal error: invalid SKI redex")
      modify (\state -> state{steps = steps state + 1})
      whnf address

normalize :: Address -> Run ()
normalize address = do
  whnf address
  node <- readNode address
  case node of
    App function argument -> do
      normalize function
      normalize argument
      before <- gets steps
      whnf address
      after <- gets steps
      when (after > before) (normalize address)
    _ -> pure ()

serialize :: Address -> Run Graph.Graph
serialize root = do
  (_, definitions) <- emit Map.empty root
  pure (Graph.GGraph definitions)
 where
  emit seen address = do
    actual <- resolve address
    case Map.lookup actual seen of
      Just _ -> pure (seen, [])
      Nothing -> do
        let number = Map.size seen
            seen' = Map.insert actual number seen
            nodeId n = Graph.NodeId ('#' : show n)
        node <- readNode actual
        case node of
          S -> pure (seen', [Graph.NS (nodeId number)])
          K -> pure (seen', [Graph.NK (nodeId number)])
          I -> pure (seen', [Graph.NI (nodeId number)])
          App function argument -> do
            (afterFunction, functionDefs) <- emit seen' function
            (afterArgument, argumentDefs) <- emit afterFunction argument
            functionAddress <- resolve function
            argumentAddress <- resolve argument
            let definition =
                  Graph.NApp
                    (nodeId number)
                    (nodeId (afterArgument Map.! functionAddress))
                    (nodeId (afterArgument Map.! argumentAddress))
            pure (afterArgument, definition : functionDefs ++ argumentDefs)
          Indirect _ -> lift (Left "internal error: unresolved indirection")
          ProbeFunction -> lift (Left "internal error: cannot serialize probe function")
          ProbeValue -> lift (Left "internal error: cannot serialize probe value")
          ChurchNumeral _ -> lift (Left "internal error: cannot serialize Church numeral")
