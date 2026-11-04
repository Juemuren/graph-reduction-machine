module Main (main) where

import Compiler (compileSource)
import Interpreter (decodeBoolean, decodeInteger, decodeNatural, interpret)
import System.Exit (die)
import TestSupport (assertGraphResult, runCases)

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
    "test/cases/integration/if"
    ".lambda"
    ".decoded"
    checkDecodedNatural
  putStrLn "integration tests passed"

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
