module Main (main) where

import LanguageServer (runLanguageServer)
import System.Exit (ExitCode (..), exitWith)

main :: IO ()
main =
  runLanguageServer >>= \code -> exitWith (if code == 0 then ExitSuccess else ExitFailure code)
