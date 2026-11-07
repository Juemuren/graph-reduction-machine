module Main (main) where

import Control.Monad (when)
import System.Exit (ExitCode (..), die)
import System.Process (readProcessWithExitCode)
import TestSupport (CliCase (..), assertEqual, runCliSuite)

main :: IO ()
main = runCliSuite runCase

runCase :: String -> CliCase -> IO ()
runCase label (CliCase _ command args stdin code stdout stderr) = do
  when (command /= "lambda-to-graph" && command /= "ski-interpreter") $
    die (label ++ ": unknown command " ++ command)
  (status, output, problem) <- readProcessWithExitCode command args stdin
  assertEqual label (if code == 0 then ExitSuccess else ExitFailure code) status
  assertEqual label stdout (filter (/= '\r') output)
  assertEqual label stderr (filter (/= '\r') problem)
