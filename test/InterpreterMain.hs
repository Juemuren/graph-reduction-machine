module Main (main) where

import Control.Monad (unless)
import Data.List (isPrefixOf)
import Interpreter (interpretSource)
import Ski.Print (printTree)
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
main = do
  runSuite "interpreter" runCase
  assertStepOptions

assertStepOptions :: IO ()
assertStepOptions = do
  let source = "#0 = #1 #2;\n#1 = I;\n#2 = #3 #4;\n#3 = I;\n#4 = K;\n"
      label = "interpreter CLI step options"
  (status, output, problem) <-
    readProcessWithExitCode
      "ski-interpreter"
      ["--no-step-limit", "--show-steps"]
      source
  assertEqual label ExitSuccess status
  assertEqual label ["#0 = K;"] (normalizeGraph output)
  assertEqual label "steps: 2" (normalizeError problem)
  (decodeStatus, decodeOutput, decodeProblem) <-
    readProcessWithExitCode
      "ski-interpreter"
      ["--decode=boolean", "--no-step-limit", "--show-steps"]
      "#0 = K;\n"
  assertEqual label ExitSuccess decodeStatus
  assertEqual label "TRUE\n" decodeOutput
  assertEqual label "steps: 1" (normalizeError decodeProblem)
  (zeroStatus, _, zeroProblem) <-
    readProcessWithExitCode "ski-interpreter" ["--show-steps"] "#0 = I;\n"
  assertEqual label ExitSuccess zeroStatus
  assertEqual label "steps: 0" (normalizeError zeroProblem)
  (limitStatus, limitOutput, limitProblem) <-
    readProcessWithExitCode
      "ski-interpreter"
      ["--max-steps=1", "--show-steps"]
      source
  assertEqual label (ExitFailure 1) limitStatus
  assertEqual label "" limitOutput
  assertEqual
    label
    "reduction exceeded step limit 1"
    (normalizeError limitProblem)
  (conflictStatus, _, conflictProblem) <-
    readProcessWithExitCode
      "ski-interpreter"
      ["--max-steps=1", "--no-step-limit"]
      source
  assertEqual label (ExitFailure 1) conflictStatus
  unless ("usage: ski-interpreter" `isPrefixOf` conflictProblem) $
    die (label ++ ": expected usage error for conflicting options")
  putStrLn (label ++ ": PASS")

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
