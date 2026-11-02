module TestSupport (runCases, assertGraphResult, assertExpectedError, normalizeGraph) where

import Control.Monad (when)
import Data.List (isInfixOf, isSuffixOf, sort)
import qualified Graph.Abs as Graph
import Graph.Print (printTree)
import System.Directory (listDirectory)
import System.Exit (die)
import System.FilePath (dropExtension, takeExtension, (</>))

runCases ::
  FilePath -> String -> String -> (FilePath -> FilePath -> IO ()) -> IO ()
runCases directory sourceSuffix expectedSuffix check = do
  entries <- listDirectory directory
  let sources =
        sort
          [ directory </> name
          | name <- entries
          , takeExtension name == sourceSuffix
          , not (expectedSuffix `isSuffixOf` name)
          ]
  when (null sources) $ die ("no test cases in " ++ directory)
  mapM_ (\source -> check source (dropExtension source ++ expectedSuffix)) sources

assertGraphResult ::
  FilePath -> FilePath -> Either String Graph.Graph -> IO String
assertGraphResult sourcePath expectedPath result = do
  expected <- readFile expectedPath
  case result of
    Left problem -> die (sourcePath ++ ": " ++ problem)
    Right graph -> do
      let actual = printTree graph
      if normalizeGraph actual == normalizeGraph expected
        then pure actual
        else
          die
            ( sourcePath
                ++ ": graph differs from "
                ++ expectedPath
                ++ "\nexpected:\n"
                ++ expected
                ++ "\nactual:\n"
                ++ actual
            )

assertExpectedError :: FilePath -> FilePath -> Either String a -> IO ()
assertExpectedError sourcePath expectedPath result = do
  expected <- readFile expectedPath
  case result of
    Left problem ->
      if not (null (trim expected)) && trim expected `isInfixOf` problem
        then pure ()
        else
          die
            ( sourcePath
                ++ ": expected error containing "
                ++ show (trim expected)
                ++ ", got "
                ++ show problem
            )
    Right _ -> die (sourcePath ++ ": expected failure")

normalizeGraph :: String -> [String]
normalizeGraph = lines . filter (/= '\r')

trim :: String -> String
trim = unwords . words
