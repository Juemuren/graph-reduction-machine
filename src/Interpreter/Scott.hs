-- | Decode Scott-encoded naturals from SKI graphs.
module Interpreter.Scott (
  decodeScottNaturalSource,
  decodeScottNaturalSourceWithSteps,
  decodeScottNatural,
) where

import Interpreter.Machine
import Numeric.Natural (Natural)
import qualified Ski.Abs as Graph
import qualified Ski.Par as Graph

decodeScottNaturalSource :: Int -> String -> Either String (Maybe Natural)
decodeScottNaturalSource limit source =
  fst <$> decodeScottNaturalSourceWithSteps (Just limit) source

decodeScottNaturalSourceWithSteps ::
  Maybe Int -> String -> Either String (Maybe Natural, Natural)
decodeScottNaturalSourceWithSteps limit source =
  Graph.pGraph (Graph.myLexer source) >>= \graph ->
    runGraphWithSteps limit graph decodeScottNaturalAt

decodeScottNatural :: Int -> Graph.Graph -> Either String (Maybe Natural)
decodeScottNatural limit graph = runGraph limit graph decodeScottNaturalAt

decodeScottNaturalAt :: Address -> Run (Maybe Natural)
decodeScottNaturalAt root = do
  zero <- allocate ProbeFunction
  successor <- allocate ProbeValue
  go zero successor root 0
 where
  go zero successor current count = do
    appliedOnce <- allocate (App current zero)
    appliedTwice <- allocate (App appliedOnce successor)
    whnf appliedTwice
    (headNode, applications) <- spine appliedTwice
    case (headNode, applications) of
      (ProbeFunction, []) -> pure (Just count)
      (ProbeValue, [(_, predecessor)]) ->
        go zero successor predecessor (count + 1)
      _ -> pure Nothing
