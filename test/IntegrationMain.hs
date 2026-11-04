module Main (main) where

import TestSupport (Suite (IntegrationSuite), runSuite)

main :: IO ()
main = runSuite IntegrationSuite
