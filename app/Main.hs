module Main (main) where

import Compiler (compileSource)
import Graph.Print (printTree)
import System.Environment (getArgs)
import System.Exit (die, exitFailure)
import System.IO (hPutStrLn, stderr)

main :: IO ()
main = do
  args <- getArgs
  source <- case args of
    [] -> getContents
    [path] -> readFile path
    _ -> die "usage: lambda-to-graph [FILE]"
  case compileSource source of
    Left message -> do
      hPutStrLn stderr ("lambda-to-graph: " ++ message)
      exitFailure
    Right graph -> putStrLn (printTree graph)
