module Main (main) where

import Control.Monad (unless)
import Graph.Print (printTree)
import Interpreter (interpretSource)
import System.Exit (ExitCode (..), die)
import System.Process (readProcessWithExitCode)
import TestSupport (
  Expected (..),
  Input (..),
  RunSpec (..),
  TestCase (..),
  assertEqual,
  assertError,
  assertGraph,
  caseLimit,
  normalizeError,
  normalizeGraph,
  runSuite,
  unwrap,
 )

main :: IO ()
main = runSuite "interpreter" runCase

runCase :: String -> TestCase -> IO ()
runCase label (TestCase _ (Input language source _) spec expected) = do
  let defaultLimit = if runStage spec == "interpret" then 100 else 100000
  limit <- caseLimit label defaultLimit spec
  case (language, runStage spec, expected) of
    ("ski", "interpret", ExpectedGraph graph) -> do
      actual <- assertGraph label graph (interpretSource limit source)
      again <- unwrap label (interpretSource limit actual)
      assertEqual label (normalizeGraph actual) (normalizeGraph (printTree again))
    ("ski", "interpret", ExpectedError problem) ->
      assertError label problem (interpretSource limit source)
    ("ski", "decode", ExpectedError problem) ->
      assertDecodeCliError label source spec limit problem
    _ -> die (label ++ ": unsupported input, run, or expect combination")

assertDecodeCliError :: String -> String -> RunSpec -> Int -> String -> IO ()
assertDecodeCliError label source spec limit expected = do
  decodeType <-
    maybe (die (label ++ ": decode type is required")) pure (runDecode spec)
  let options =
        ["--max-steps=" ++ show limit, "--decode=" ++ decodeType]
          ++ maybe [] (\index -> ["--precision-real=" ++ show index]) (runPrecisionReal spec)
  (status, output, problem) <-
    readProcessWithExitCode "ski-interpreter" options source
  unless (status == ExitFailure 1 && null output) $
    die
      ( label
          ++ ": expected exit 1 and empty stdout, got "
          ++ show (status, output, problem)
      )
  assertEqual label (normalizeError expected) (normalizeError problem)
