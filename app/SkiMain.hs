module Main (main) where

import Graph.Print (printTree)
import Interpreter (interpretSource)
import System.Environment (getArgs)
import System.Exit (die, exitFailure)
import System.IO (hPutStrLn, stderr)
import Text.Read (readMaybe)

main :: IO ()
main = do
  args <- getArgs
  (limit, path) <- either die pure (parseArgs args)
  source <- maybe getContents readFile path
  case interpretSource limit source of
    Left message -> do
      hPutStrLn stderr ("ski-interpreter: " ++ message)
      exitFailure
    Right graph -> putStrLn (printTree graph)

parseArgs :: [String] -> Either String (Int, Maybe FilePath)
parseArgs = go 100000 Nothing
  where
    usage = "usage: ski-interpreter [--max-steps N] [FILE]"
    go limit path [] = Right (limit, path)
    go _ path ("--max-steps" : value : rest) =
      case readMaybe value of
        Just limit | limit > 0 -> go limit path rest
        _ -> Left usage
    go limit Nothing (value@(first : _) : rest)
      | first /= '-' = go limit (Just value) rest
    go _ _ _ = Left usage
