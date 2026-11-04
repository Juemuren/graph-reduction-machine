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
    "test/cases/integration/operation"
    ".lambda"
    ".decoded"
    checkDecodedNatural
  runCases
    "test/cases/integration/construction-boolean"
    ".lambda"
    ".decoded"
    checkDecodedBoolean
  runCases
    "test/cases/integration/operation-boolean"
    ".lambda"
    ".decoded"
    checkDecodedBoolean
  runCases
    "test/cases/integration/construction-pair"
    ".lambda"
    ".decoded"
    checkDecodedBoolean
  runCases
    "test/cases/integration/operation-pair"
    ".lambda"
    ".decoded"
    checkDecodedBoolean
  runCases
    "test/cases/integration/construction-natural"
    ".lambda"
    ".decoded"
    checkDecodedNatural
  runCases
    "test/cases/integration/operation-natural"
    ".lambda"
    ".decoded"
    checkDecodedNatural
  runCases
    "test/cases/integration/comparison-natural"
    ".lambda"
    ".decoded"
    checkDecodedBoolean
  runCases
    "test/cases/integration/construction-integer"
    ".lambda"
    ".decoded"
    checkDecodedInteger
  runCases
    "test/cases/integration/operation-integer"
    ".lambda"
    ".decoded"
    checkDecodedInteger
  runCases
    "test/cases/integration/comparison-integer"
    ".lambda"
    ".decoded"
    checkDecodedBoolean
  runCases
    "test/cases/integration/deconstruction-integer"
    ".lambda"
    ".decoded"
    checkDecodedNatural
  runCases
    "test/cases/integration/construction-rational"
    ".lambda"
    ".decoded"
    checkDecodedRational
  runCases
    "test/cases/integration/operation-rational"
    ".lambda"
    ".decoded"
    checkDecodedRational
  runCases
    "test/cases/integration/comparison-rational"
    ".lambda"
    ".decoded"
    checkDecodedBoolean
  runCases
    "test/cases/integration/deconstruction-rational"
    ".lambda"
    ".decoded"
    checkDecodedInteger
  runCases
    "test/cases/integration/construction-real"
    ".lambda"
    ".decoded"
    checkConstructedReal
  runCases
    "test/cases/integration/deconstruction-real"
    ".lambda"
    ".decoded"
    checkDecodedRational
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
  checkRationalSource sourcePath expectedPath source
  putStrLn (sourcePath ++ ": PASS")

checkConstructedReal :: FilePath -> FilePath -> IO ()
checkConstructedReal sourcePath expectedPath = do
  source <- readFile sourcePath
  let real = "(" ++ source ++ ")"
  mapM_
    (\index -> checkRationalSource sourcePath expectedPath (real ++ " " ++ index))
    ["ZERO", "THREE"]
  putStrLn (sourcePath ++ ": PASS")

checkRationalSource :: FilePath -> FilePath -> String -> IO ()
checkRationalSource sourcePath expectedPath source = do
  expected <- readFile expectedPath
  case compileSource source >>= decodeRational 100000 of
    Left problem -> die (sourcePath ++ ": " ++ problem)
    Right (Just actual)
      | show (numerator actual) ++ "/" ++ show (denominator actual)
          == unwords (words expected) ->
          pure ()
    Right actual ->
      die
        (sourcePath ++ ": expected " ++ show expected ++ ", decoded " ++ show actual)
