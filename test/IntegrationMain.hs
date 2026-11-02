module Main (main) where

import Compiler (compileSource)
import Data.List (sort)
import Graph.Print (printTree)
import Interpreter (decodeChurch, interpret)
import System.Directory (listDirectory)
import System.Exit (die)
import System.FilePath ((</>), dropExtension, takeExtension)

main :: IO ()
main = do
  let directory = "test/cases/integration/undecode"
  entries <- listDirectory directory
  let sources = sort
        [ directory </> name
        | name <- entries
        , takeExtension name == ".lambda"
        ]
  if null sources then die ("no test cases in " ++ directory) else pure ()
  mapM_ check sources
  let decodeDirectory = "test/cases/integration/decode"
  decodeEntries <- listDirectory decodeDirectory
  let decodeSources = sort
        [ decodeDirectory </> name
        | name <- decodeEntries
        , takeExtension name == ".lambda"
        ]
  if null decodeSources then die ("no test cases in " ++ decodeDirectory) else pure ()
  mapM_ checkDecoded decodeSources
  putStrLn "integration tests passed"

checkDecoded :: FilePath -> IO ()
checkDecoded sourcePath = do
  let expectedPath = dropExtension sourcePath ++ ".decoded"
  source <- readFile sourcePath
  expected <- readFile expectedPath
  case compileSource source >>= decodeChurch 100000 of
    Left problem -> die (sourcePath ++ ": " ++ problem)
    Right (Just actual) | show actual == unwords (words expected) ->
      putStrLn (sourcePath ++ ": PASS")
    Right actual -> die (sourcePath ++ ": expected " ++ show expected
                         ++ ", decoded " ++ show actual)

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
