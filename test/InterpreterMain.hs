module Main (main) where

import TestSupport (Suite (InterpreterSuite), runSuite)

main :: IO ()
main = runSuite InterpreterSuite
