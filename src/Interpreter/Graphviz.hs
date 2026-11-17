-- | Render SKI graphs as Graphviz DOT source.
module Interpreter.Graphviz (renderGraphviz) where

import Data.List (intercalate)
import qualified Ski.Abs as Graph

renderGraphviz :: Graph.Graph -> String
renderGraphviz (Graph.GGraph definitions) =
  intercalate
    "\n"
    ( ["digraph ski {", "  node [shape=circle];"]
        ++ concatMap renderDefinition definitions
        ++ ["}"]
    )
 where
  renderDefinition definition = case definition of
    Graph.NS name -> [renderNode name "S"]
    Graph.NK name -> [renderNode name "K"]
    Graph.NI name -> [renderNode name "I"]
    Graph.NApp name function argument ->
      [ renderNode name "@"
      , renderEdge name function "function"
      , renderEdge name argument "argument"
      ]

  renderNode name label =
    "  "
      ++ quoted name
      ++ " [label="
      ++ show (nodeName name ++ ": " ++ label)
      ++ "];"

  renderEdge source target label =
    "  "
      ++ quoted source
      ++ " -> "
      ++ quoted target
      ++ " [label="
      ++ show label
      ++ "];"

  quoted = show . nodeName

  nodeName (Graph.NodeId name) = name
