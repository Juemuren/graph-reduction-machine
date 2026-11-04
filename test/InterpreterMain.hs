module Main (main) where

import Graph.Print (printTree)
import Interpreter (interpretSource)
import System.Exit (ExitCode (..), die)
import System.Process (readProcessWithExitCode)
import TestSupport (
  assertExpectedError,
  assertExpectedErrorText,
  assertGraphResult,
  normalizeGraph,
  runCases,
 )

main :: IO ()
main = do
  runCases "test/cases/interpreter/reduce" ".ski" ".reduced.ski" (checkResult 100)
  runCases "test/cases/interpreter/errors" ".ski" ".error" (checkError 100)
  runCases "test/cases/interpreter/limit-errors" ".ski" ".error" (checkError 1)
  runCases
    "test/cases/interpreter/decode-limit-errors"
    ".ski"
    ".error"
    (checkDecodeError ["--max-steps=1", "--decode=natural"])
  runCases
    "test/cases/interpreter/decode-natural-errors"
    ".ski"
    ".error"
    (checkDecodeError ["--decode=natural"])
  runCases
    "test/cases/interpreter/decode-boolean-errors"
    ".ski"
    ".error"
    (checkDecodeError ["--decode=boolean"])
  runCases
    "test/cases/interpreter/decode-integer-errors"
    ".ski"
    ".error"
    (checkDecodeError ["--decode=integer"])
  runCases
    "test/cases/interpreter/decode-rational-errors"
    ".ski"
    ".error"
    (checkDecodeError ["--decode=rational"])
  putStrLn "interpreter tests passed"

checkResult :: Int -> FilePath -> FilePath -> IO ()
checkResult limit sourcePath expectedPath = do
  source <- readFile sourcePath
  actual <-
    assertGraphResult sourcePath expectedPath (interpretSource limit source)
  case interpretSource limit actual of
    Left problem -> die (sourcePath ++ ": output cannot be parsed: " ++ problem)
    Right again ->
      if normalizeGraph (printTree again) == normalizeGraph actual
        then putStrLn (sourcePath ++ ": PASS")
        else die (sourcePath ++ ": output changes on second interpretation")

checkError :: Int -> FilePath -> FilePath -> IO ()
checkError limit sourcePath expectedPath = do
  source <- readFile sourcePath
  assertExpectedError sourcePath expectedPath (interpretSource limit source)
  putStrLn (sourcePath ++ ": PASS")

checkDecodeError :: [String] -> FilePath -> FilePath -> IO ()
checkDecodeError options sourcePath expectedPath = do
  (exitCode, output, errors) <-
    readProcessWithExitCode "ski-interpreter" (options ++ [sourcePath]) ""
  if exitCode /= ExitFailure 1 || not (null output)
    then
      die
        ( sourcePath
            ++ ": expected exit 1 and empty stdout, got "
            ++ show (exitCode, output, errors)
        )
    else do
      assertExpectedErrorText sourcePath expectedPath errors
      putStrLn (sourcePath ++ ": PASS")
