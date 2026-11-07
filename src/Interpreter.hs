-- | Reduce SKI graphs and decode Church-encoded values.
module Interpreter (
  interpretSource,
  interpretSourceWithSteps,
  interpret,
  decodeNaturalSource,
  decodeNaturalSourceWithSteps,
  decodeNatural,
  decodeBooleanSource,
  decodeBooleanSourceWithSteps,
  decodeBoolean,
  decodeIntegerSource,
  decodeIntegerSourceWithSteps,
  decodeInteger,
  decodeRationalSource,
  decodeRationalSourceWithSteps,
  decodeRational,
  decodeRealSource,
  decodeRealSourceWithSteps,
  decodeReal,
) where

import Interpreter.Church (
  decodeBoolean,
  decodeBooleanSource,
  decodeBooleanSourceWithSteps,
  decodeInteger,
  decodeIntegerSource,
  decodeIntegerSourceWithSteps,
  decodeNatural,
  decodeNaturalSource,
  decodeNaturalSourceWithSteps,
  decodeRational,
  decodeRationalSource,
  decodeRationalSourceWithSteps,
  decodeReal,
  decodeRealSource,
  decodeRealSourceWithSteps,
 )
import Interpreter.Machine (normalize, runGraph, runGraphWithSteps, serialize)
import Numeric.Natural (Natural)
import qualified Ski.Abs as Graph
import qualified Ski.Par as Graph

interpretSource :: Int -> String -> Either String Graph.Graph
interpretSource limit source =
  Graph.pGraph (Graph.myLexer source) >>= interpret limit

interpretSourceWithSteps ::
  Maybe Int -> String -> Either String (Graph.Graph, Natural)
interpretSourceWithSteps limit source =
  Graph.pGraph (Graph.myLexer source) >>= \graph ->
    runGraphWithSteps limit graph (\root -> normalize root >> serialize root)

interpret :: Int -> Graph.Graph -> Either String Graph.Graph
interpret limit graph =
  runGraph limit graph (\root -> normalize root >> serialize root)
