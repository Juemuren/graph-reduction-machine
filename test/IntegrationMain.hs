module Main (main) where

import Compiler (compileSource)
import Interpreter (decodeBoolean, decodeChurch, interpret)
import System.Exit (die)
import TestSupport (assertGraphResult, runCases)

main :: IO ()
main = do
  runCases "test/cases/integration/undecode" ".lambda" ".ski" checkUndecode
  runCases "test/cases/integration/decode-number" ".lambda" ".decoded" checkDecodedNumber
  runCases "test/cases/integration/decode-boolean" ".lambda" ".decoded" checkDecodedBoolean
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

checkDecodedNumber :: FilePath -> FilePath -> IO ()
checkDecodedNumber sourcePath expectedPath = do
  source <- readFile sourcePath
  expected <- readFile expectedPath
  case compileSource source >>= decodeChurch 100000 of
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
