-- | Change the sharing of a normalized SKI graph before rendering it.
module Interpreter.Share (ShareMode (..), shareGraph) where

import Control.Monad.State.Strict (State, get, modify, runState)
import qualified Data.IntMap.Strict as IntMap
import qualified Data.Map.Strict as Map
import qualified Ski.Abs as Graph

data ShareMode = Preserve | Merge | Unfold deriving (Eq, Show)

data Shape a = S | K | I | App a a deriving (Eq, Ord)

data Intern = Intern
  { originals :: Map.Map Graph.NodeId Int
  , shapes :: Map.Map (Shape Int) Int
  , nodes :: IntMap.IntMap (Shape Int)
  }

shareGraph :: ShareMode -> Graph.Graph -> Graph.Graph
shareGraph Preserve graph = graph
shareGraph Merge (Graph.GGraph definitions) =
  let source =
        Map.fromList [(definitionId definition, definition) | definition <- definitions]
      (canonicalRoot, interned) = runState (intern source (Graph.NodeId "#0")) emptyIntern
   in render True (nodes interned IntMap.!) canonicalRoot
shareGraph Unfold (Graph.GGraph definitions) =
  let source =
        Map.fromList [(definitionId definition, definition) | definition <- definitions]
   in render False (definitionShape source) (Graph.NodeId "#0")

emptyIntern :: Intern
emptyIntern = Intern Map.empty Map.empty IntMap.empty

definitionId :: Graph.NodeDef -> Graph.NodeId
definitionId definition = case definition of
  Graph.NS name -> name
  Graph.NK name -> name
  Graph.NI name -> name
  Graph.NApp name _ _ -> name

definitionShape ::
  Map.Map Graph.NodeId Graph.NodeDef -> Graph.NodeId -> Shape Graph.NodeId
definitionShape source name = case source Map.! name of
  Graph.NS _ -> S
  Graph.NK _ -> K
  Graph.NI _ -> I
  Graph.NApp _ function argument -> App function argument

intern :: Map.Map Graph.NodeId Graph.NodeDef -> Graph.NodeId -> State Intern Int
intern source name = do
  state <- get
  case Map.lookup name (originals state) of
    Just canonical -> pure canonical
    Nothing -> do
      shape <- case definitionShape source name of
        S -> pure S
        K -> pure K
        I -> pure I
        App function argument -> App <$> intern source function <*> intern source argument
      current <- get
      let canonical = Map.findWithDefault (IntMap.size (nodes current)) shape (shapes current)
      modify
        ( \next ->
            next
              { originals = Map.insert name canonical (originals next)
              , shapes = Map.insert shape canonical (shapes next)
              , nodes = IntMap.insert canonical shape (nodes next)
              }
        )
      pure canonical

render :: (Ord a) => Bool -> (a -> Shape a) -> a -> Graph.Graph
render reuse shapeOf root =
  let (_, _, definitions, _) = emit 0 Map.empty root
   in Graph.GGraph definitions
 where
  emit next seen address =
    case if reuse then Map.lookup address seen else Nothing of
      Just number -> (next, seen, [], number)
      Nothing ->
        let number = next
            seen' = if reuse then Map.insert address number seen else seen
            nodeId n = Graph.NodeId ('#' : show n)
         in case shapeOf address of
              S -> (next + 1, seen', [Graph.NS (nodeId number)], number)
              K -> (next + 1, seen', [Graph.NK (nodeId number)], number)
              I -> (next + 1, seen', [Graph.NI (nodeId number)], number)
              App function argument ->
                let (afterFunction, seenFunction, functionDefs, functionNumber) =
                      emit (next + 1) seen' function
                    (afterArgument, seenArgument, argumentDefs, argumentNumber) =
                      emit afterFunction seenFunction argument
                    definition =
                      Graph.NApp (nodeId number) (nodeId functionNumber) (nodeId argumentNumber)
                 in (afterArgument, seenArgument, definition : functionDefs ++ argumentDefs, number)
