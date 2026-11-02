module Main (main) where

import Graph.Print (printTree)
import Interpreter (decodeChurchSource, interpretSource)
import System.Exit (die)
import TestSupport (assertExpectedError, assertGraphResult, normalizeGraph, runCases)

main :: IO ()
main = do
  runCases "test/cases/interpreter/reduce" ".ski" ".reduced.ski" (checkResult 100)
  runCases "test/cases/interpreter/errors" ".ski" ".error" (checkError 100)
  runCases "test/cases/interpreter/limit-errors" ".ski" ".error" (checkError 1)
  runCases "test/cases/interpreter/decode-errors" ".ski" ".error" (checkDecodeError 100)
  runCases "test/cases/interpreter/decode-limit-errors" ".ski" ".error" (checkDecodeError 1)
  putStrLn "interpreter tests passed"

checkResult :: Int -> FilePath -> FilePath -> IO ()
checkResult limit sourcePath expectedPath = do
  source <- readFile sourcePath
  actual <- assertGraphResult sourcePath expectedPath (interpretSource limit source)
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

checkDecodeError :: Int -> FilePath -> FilePath -> IO ()
checkDecodeError limit sourcePath expectedPath = do
  source <- readFile sourcePath
  let result = decodeChurchSource limit source
               >>= maybe (Left "not a Church numeral") Right
  assertExpectedError sourcePath expectedPath result
  putStrLn (sourcePath ++ ": PASS")
