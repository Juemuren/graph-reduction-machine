module Main (main) where

import Compiler (compileSource)
import Data.List (sort)
import Graph.Print (printTree)
import Interpreter (interpret)
import System.Directory (listDirectory)
import System.Exit (die)
import System.FilePath ((</>), dropExtension, takeExtension)

main :: IO ()
main = do
  let directory = "test/cases/integration"
  entries <- listDirectory directory
  let sources = sort
        [ directory </> name
        | name <- entries
        , takeExtension name == ".lambda"
        ]
  if null sources then die ("no test cases in " ++ directory) else pure ()
  mapM_ check sources
  putStrLn "integration tests passed"

check :: FilePath -> IO ()
check sourcePath = do
  let expectedPath = dropExtension sourcePath ++ ".ski"
  source <- readFile sourcePath
  expected <- readFile expectedPath
  case compileSource source >>= interpret 100000 of
    Left problem -> die (sourcePath ++ ": " ++ problem)
    Right graph -> do
      let actual = printTree graph
      if normalize actual == normalize expected
        then putStrLn (sourcePath ++ ": PASS")
        else die (sourcePath ++ ": graph differs from " ++ expectedPath
                  ++ "\nexpected:\n" ++ expected ++ "\nactual:\n" ++ actual)

normalize :: String -> [String]
normalize = lines . filter (/= '\r')
