-- | Decode Scott-style binary naturals from SKI graphs.
module Interpreter.Binary (
  decodeBinaryNaturalSource,
  decodeBinaryNaturalSourceWithSteps,
  decodeBinaryNatural,
  decodeBinaryNaturalAt,
) where

import Interpreter.Machine
import Numeric.Natural (Natural)
import qualified Ski.Abs as Graph
import qualified Ski.Par as Graph

decodeBinaryNaturalSource :: Int -> String -> Either String (Maybe Natural)
decodeBinaryNaturalSource limit source =
  fst <$> decodeBinaryNaturalSourceWithSteps (Just limit) source

decodeBinaryNaturalSourceWithSteps ::
  Maybe Int -> String -> Either String (Maybe Natural, Natural)
decodeBinaryNaturalSourceWithSteps limit source =
  Graph.pGraph (Graph.myLexer source) >>= \graph ->
    runGraphWithSteps limit graph decodeBinaryNaturalAt

decodeBinaryNatural :: Int -> Graph.Graph -> Either String (Maybe Natural)
decodeBinaryNatural limit graph = runGraph limit graph decodeBinaryNaturalAt

decodeBinaryNaturalAt :: Address -> Run (Maybe Natural)
decodeBinaryNaturalAt root = do
  zero <- allocate ProbeFunction
  evenBranch <- allocate ProbeValue
  oddBranch <- allocate ProbeBit
  go zero evenBranch oddBranch root
 where
  go zero evenBranch oddBranch current = do
    appliedZero <- allocate (App current zero)
    appliedEven <- allocate (App appliedZero evenBranch)
    appliedOdd <- allocate (App appliedEven oddBranch)
    whnf appliedOdd
    (headNode, applications) <- spine appliedOdd
    case (headNode, applications) of
      (ProbeFunction, []) -> pure (Just 0)
      (ProbeValue, [(_, predecessor)]) ->
        fmap (2 *) <$> go zero evenBranch oddBranch predecessor
      (ProbeBit, [(_, predecessor)]) ->
        fmap (\n -> 2 * n + 1) <$> go zero evenBranch oddBranch predecessor
      _ -> pure Nothing
