-- | Render SKI graphs as Mermaid flowcharts.
module Interpreter.Mermaid (renderMermaid) where

import Data.List (intercalate)
import qualified Ski.Abs as Graph

renderMermaid :: Graph.Graph -> String
renderMermaid (Graph.GGraph definitions) =
  intercalate "\n" ("flowchart TD" : concatMap renderDefinition definitions)
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
    "  " ++ nodeId name ++ "((\"" ++ nodeName name ++ ": " ++ label ++ "\"))"

  renderEdge source target label =
    "  " ++ nodeId source ++ " -->|" ++ label ++ "| " ++ nodeId target

  nodeId = ('n' :) . drop 1 . nodeName

  nodeName (Graph.NodeId name) = name
