module Main (main) where

import TestSupport (Suite (CompilerSuite), runSuite)

main :: IO ()
main = runSuite CompilerSuite
