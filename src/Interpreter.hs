-- | Reduce a parsed SKI graph to normal form while preserving shared nodes.
module Interpreter (interpretSource, interpret, decodeChurchSource, decodeChurch) where

import Control.Monad (foldM, when)
import Control.Monad.State.Strict (StateT, evalStateT, get, gets, lift, modify)
import qualified Data.IntMap.Strict as IntMap
import qualified Data.Map.Strict as Map
import qualified Data.Set as Set
import qualified Graph.Abs as Graph
import qualified Graph.Par as Graph

type Address = Int

data Node
  = S
  | K
  | I
  | App Address Address
  | Indirect Address
  | ProbeFunction
  | ProbeValue

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
decodeChurchSource :: Int -> String -> Either String (Maybe Integer)
decodeChurchSource limit source =
  Graph.pGraph (Graph.myLexer source) >>= decodeChurch limit

decodeChurch :: Int -> Graph.Graph -> Either String (Maybe Integer)
decodeChurch limit graph = do
  (initialHeap, root) <- loadGraph graph
  let machine = Machine initialHeap (IntMap.size initialHeap) 0 limit
  evalStateT
    ( do
        function <- allocate ProbeFunction
        value <- allocate ProbeValue
        appliedOnce <- allocate (App root function)
        appliedTwice <- allocate (App appliedOnce value)
        normalize appliedTwice
        countApplications function value appliedTwice 0
    )
    machine

countApplications ::
  Address -> Address -> Address -> Integer -> Run (Maybe Integer)
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
