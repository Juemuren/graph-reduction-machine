module Main (main) where

import Compiler (Reduction (NoReduction), compileSource, compileSourceWith)
import Data.Ratio (denominator, numerator)
import Interpreter (
  decodeBoolean,
  decodeInteger,
  decodeNatural,
  decodeRational,
  interpret,
 )
import System.Exit (die)
import TestSupport (assertExpectedError, assertGraphResult, runCases)

main :: IO ()
main = do
  runCases "test/cases/integration/undecode" ".lambda" ".ski" checkUndecode
  runCases
    "test/cases/integration/decode-natural"
    ".lambda"
    ".decoded"
    checkDecodedNatural
  runCases
    "test/cases/integration/decode-boolean"
    ".lambda"
    ".decoded"
    checkDecodedBoolean
  runCases
    "test/cases/integration/decode-integer"
    ".lambda"
    ".decoded"
    checkDecodedInteger
  runCases
    "test/cases/integration/decode-rational"
    ".lambda"
    ".decoded"
    checkDecodedRational
  runCases
    "test/cases/integration/operation-natural"
    ".lambda"
    ".decoded"
    checkDecodedNatural
  runCases
    "test/cases/integration/operation-pair"
    ".lambda"
    ".decoded"
    checkDecodedNatural
  runCases
    "test/cases/integration/operation-boolean"
    ".lambda"
    ".decoded"
    checkDecodedBoolean
  runCases
    "test/cases/integration/operation-integer"
    ".lambda"
    ".decoded"
    checkDecodedInteger
  runCases
    "test/cases/integration/operation-rational"
    ".lambda"
    ".decoded"
    checkDecodedInteger
  runCases
    "test/cases/integration/control-if"
    ".lambda"
    ".decoded"
    checkDecodedNatural
  runCases
    "test/cases/integration/control-loop"
    ".lambda"
    ".decoded"
    checkDecodedNatural
  runCases
    "test/cases/integration/control-loop-limit"
    ".lambda"
    ".error"
    checkLoopLimit
  putStrLn "integration tests passed"

checkLoopLimit :: FilePath -> FilePath -> IO ()
checkLoopLimit sourcePath expectedPath = do
  source <- readFile sourcePath
  assertExpectedError
    sourcePath
    expectedPath
    (compileSourceWith NoReduction source >>= decodeNatural 100)
  putStrLn (sourcePath ++ ": PASS")

checkUndecode :: FilePath -> FilePath -> IO ()
checkUndecode sourcePath expectedPath = do
  source <- readFile sourcePath
  _ <-
    assertGraphResult
      sourcePath
      expectedPath
      (compileSource source >>= interpret 100000)
  putStrLn (sourcePath ++ ": PASS")

checkDecodedNatural :: FilePath -> FilePath -> IO ()
checkDecodedNatural sourcePath expectedPath = do
  source <- readFile sourcePath
  expected <- readFile expectedPath
  case compileSource source >>= decodeNatural 100000 of
    Left problem -> die (sourcePath ++ ": " ++ problem)
    Right (Just actual)
      | show actual == unwords (words expected) ->
          putStrLn (sourcePath ++ ": PASS")
    Right actual ->
      die
        ( sourcePath
            ++ ": expected "
            ++ show expected
            ++ ", decoded "
            ++ show actual
        )

checkDecodedBoolean :: FilePath -> FilePath -> IO ()
checkDecodedBoolean sourcePath expectedPath = do
  source <- readFile sourcePath
  expected <- readFile expectedPath
  case compileSource source >>= decodeBoolean 100000 of
    Left problem -> die (sourcePath ++ ": " ++ problem)
    Right (Just actual)
      | show actual == unwords (words expected) ->
          putStrLn (sourcePath ++ ": PASS")
    Right actual ->
      die
        ( sourcePath
            ++ ": expected "
            ++ show expected
            ++ ", decoded "
            ++ show actual
        )

checkDecodedInteger :: FilePath -> FilePath -> IO ()
checkDecodedInteger sourcePath expectedPath = do
  source <- readFile sourcePath
  expected <- readFile expectedPath
  case compileSource source >>= decodeInteger 100000 of
    Left problem -> die (sourcePath ++ ": " ++ problem)
    Right (Just actual)
      | show actual == unwords (words expected) ->
          putStrLn (sourcePath ++ ": PASS")
    Right actual ->
      die
        ( sourcePath
            ++ ": expected "
            ++ show expected
            ++ ", decoded "
            ++ show actual
        )

checkDecodedRational :: FilePath -> FilePath -> IO ()
checkDecodedRational sourcePath expectedPath = do
  source <- readFile sourcePath
  expected <- readFile expectedPath
  case compileSource source >>= decodeRational 100000 of
    Left problem -> die (sourcePath ++ ": " ++ problem)
    Right (Just actual)
      | show (numerator actual) ++ "/" ++ show (denominator actual)
          == unwords (words expected) ->
          putStrLn (sourcePath ++ ": PASS")
    Right actual ->
      die
        (sourcePath ++ ": expected " ++ show expected ++ ", decoded " ++ show actual)
