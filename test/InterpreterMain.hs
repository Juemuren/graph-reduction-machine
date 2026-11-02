module Main (main) where

import Data.List (isInfixOf, isSuffixOf, sort)
import Graph.Print (printTree)
import Interpreter (interpretSource)
import System.Directory (listDirectory)
import System.Exit (die)
import System.FilePath ((</>), dropExtension, takeExtension)

main :: IO ()
main = do
  runCases "test/cases/interpreter/reduce" ".reduced.ski" (checkResult 100)
  runCases "test/cases/interpreter/errors" ".error" (checkError 100)
  runCases "test/cases/interpreter/step-limit" ".error" (checkError 1)
  putStrLn "interpreter tests passed"

runCases :: FilePath -> String -> (FilePath -> FilePath -> IO ()) -> IO ()
runCases directory expectedSuffix check = do
  entries <- listDirectory directory
  let sources = sort
        [ directory </> name
        | name <- entries
        , takeExtension name == ".ski"
        , not (".reduced.ski" `isSuffixOf` name)
        ]
  if null sources then die ("no test cases in " ++ directory) else pure ()
  mapM_ (\source -> check source (dropExtension source ++ expectedSuffix)) sources

checkResult :: Int -> FilePath -> FilePath -> IO ()
checkResult limit sourcePath expectedPath = do
  source <- readFile sourcePath
  expected <- readFile expectedPath
  case interpretSource limit source of
    Left problem -> die (sourcePath ++ ": " ++ problem)
    Right graph -> do
      let actual = printTree graph
      if normalize actual /= normalize expected
        then die (sourcePath ++ ": graph differs from " ++ expectedPath
                  ++ "\nexpected:\n" ++ expected ++ "\nactual:\n" ++ actual)
        else case interpretSource limit actual of
          Left problem -> die (sourcePath ++ ": output cannot be parsed: " ++ problem)
          Right again ->
            if normalize (printTree again) == normalize actual
              then putStrLn (sourcePath ++ ": PASS")
              else die (sourcePath ++ ": output changes on second interpretation")

checkError :: Int -> FilePath -> FilePath -> IO ()
checkError limit sourcePath expectedPath = do
  source <- readFile sourcePath
  expected <- readFile expectedPath
  case interpretSource limit source of
    Left problem ->
      if not (null (trim expected)) && trim expected `isInfixOf` problem
        then putStrLn (sourcePath ++ ": PASS")
        else die (sourcePath ++ ": expected error containing " ++ show (trim expected)
                  ++ ", got " ++ problem)
    Right _ -> die (sourcePath ++ ": expected interpretation to fail")

normalize :: String -> [String]
normalize = lines . filter (/= '\r')

trim :: String -> String
trim = unwords . words
