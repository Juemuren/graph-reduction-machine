-- | Reduce SKI graphs and decode Church-encoded values.
module Interpreter (
  ShareMode (..),
  interpretSource,
  interpretSourceWithSteps,
  interpretSourceWithShareWithSteps,
  interpret,
  decodeNaturalSource,
  decodeNaturalSourceWithSteps,
  decodeNatural,
  decodeScottNaturalSource,
  decodeScottNaturalSourceWithSteps,
  decodeScottNatural,
  decodeBinaryNaturalSource,
  decodeBinaryNaturalSourceWithSteps,
  decodeBinaryNatural,
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
  DecodeType (..),
  parseDecodeType,
  decodeComposite,
  decodeCompositeSourceWithSteps,
) where

import Interpreter.Binary (
  decodeBinaryNatural,
  decodeBinaryNaturalSource,
  decodeBinaryNaturalSourceWithSteps,
 )
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
import Interpreter.Composite (
  DecodeType (..),
  decodeComposite,
  decodeCompositeSourceWithSteps,
  parseDecodeType,
 )
import Interpreter.Machine (normalize, runGraph, runGraphWithSteps, serialize)
import Interpreter.Scott (
  decodeScottNatural,
  decodeScottNaturalSource,
  decodeScottNaturalSourceWithSteps,
 )
import Interpreter.Share (ShareMode (..), shareGraph)
import Numeric.Natural (Natural)
import qualified Ski.Abs as Graph
import qualified Ski.Par as Graph

interpretSource :: Int -> String -> Either String Graph.Graph
interpretSource limit source =
  Graph.pGraph (Graph.myLexer source) >>= interpret limit

interpretSourceWithSteps ::
  Maybe Int -> String -> Either String (Graph.Graph, Natural)
interpretSourceWithSteps = interpretSourceWithShareWithSteps Preserve

interpretSourceWithShareWithSteps ::
  ShareMode -> Maybe Int -> String -> Either String (Graph.Graph, Natural)
interpretSourceWithShareWithSteps sharing limit source =
  Graph.pGraph (Graph.myLexer source) >>= \graph ->
    runGraphWithSteps
      limit
      graph
      (\root -> normalize root >> shareGraph sharing <$> serialize root)

interpret :: Int -> Graph.Graph -> Either String Graph.Graph
interpret limit graph =
  runGraph limit graph (\root -> normalize root >> serialize root)
