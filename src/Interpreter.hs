-- | Reduce SKI graphs and decode Church-encoded values.
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

import Interpreter.Church (
  decodeBoolean,
  decodeBooleanSource,
  decodeInteger,
  decodeIntegerSource,
  decodeNatural,
  decodeNaturalSource,
  decodeRational,
  decodeRationalSource,
  decodeReal,
  decodeRealSource,
 )
import Interpreter.Machine (normalize, runGraph, serialize)
import qualified Ski.Abs as Graph
import qualified Ski.Par as Graph

interpretSource :: Int -> String -> Either String Graph.Graph
interpretSource limit source =
  Graph.pGraph (Graph.myLexer source) >>= interpret limit

interpret :: Int -> Graph.Graph -> Either String Graph.Graph
interpret limit graph =
  runGraph limit graph (\root -> normalize root >> serialize root)
