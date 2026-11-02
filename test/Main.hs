module Main (main) where

import Compiler (compileSource)
import Data.List (isInfixOf, sort)
import Graph.Print (printTree)
import System.Directory (listDirectory)
import System.Exit (die)
import System.FilePath ((</>), replaceExtension, takeExtension)

main :: IO ()
main = do
  runCases "test/cases/valid" ".ski" checkGraph
  runCases "test/cases/errors" ".error" checkError
  putStrLn "compiler tests passed"

runCases :: FilePath -> String -> (FilePath -> FilePath -> IO ()) -> IO ()
runCases directory expectedExtension check = do
  entries <- listDirectory directory
  let sources = sort [directory </> name | name <- entries, takeExtension name == ".lambda"]
  if null sources then die ("no test cases in " ++ directory) else pure ()
  mapM_ (\source -> check source (replaceExtension source expectedExtension)) sources

checkGraph :: FilePath -> FilePath -> IO ()
checkGraph sourcePath expectedPath = do
  source <- readFile sourcePath
  expected <- readFile expectedPath
  case compileSource source of
    Left problem -> die (sourcePath ++ ": " ++ problem)
    Right graph -> do
      let actual = printTree graph
      if normalize actual == normalize expected
        then putStrLn (sourcePath ++ ": PASS")
        else die (sourcePath ++ ": graph differs from " ++ expectedPath
                  ++ "\nexpected:\n" ++ expected ++ "\nactual:\n" ++ actual)

checkError :: FilePath -> FilePath -> IO ()
checkError sourcePath expectedPath = do
  source <- readFile sourcePath
  expected <- readFile expectedPath
  case compileSource source of
    Left problem ->
      if not (null (trim expected)) && trim expected `isInfixOf` problem
        then putStrLn (sourcePath ++ ": PASS")
        else die (sourcePath ++ ": expected error containing " ++ show (trim expected)
                  ++ ", got " ++ show problem)
    Right _ -> die (sourcePath ++ ": expected compilation to fail")

-- Ignore platform line endings and a final newline in golden files.
normalize :: String -> [String]
normalize = lines . filter (/= '\r')

trim :: String -> String
trim = unwords . words
