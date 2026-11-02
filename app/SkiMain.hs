module Main (main) where

import Graph.Print (printTree)
import Interpreter (decodeChurchSource, interpretSource)
import System.Environment (getArgs)
import System.Exit (die, exitFailure)
import System.IO (hPutStrLn, stderr)
import Text.Read (readMaybe)

main :: IO ()
main = do
  args <- getArgs
  (limit, decode, path) <- either die pure (parseArgs args)
  source <- maybe getContents readFile path
  let result =
        if decode
          then
            decodeChurchSource limit source
              >>= maybe (Left "not a Church numeral") (Right . show)
          else fmap printTree (interpretSource limit source)
  case result of
    Left message -> do
      hPutStrLn stderr ("ski-interpreter: " ++ message)
      exitFailure
    Right output -> putStrLn output

parseArgs :: [String] -> Either String (Int, Bool, Maybe FilePath)
parseArgs = go 100000 False Nothing
 where
  usage = "usage: ski-interpreter [--max-steps N] [--decode-church] [FILE]"
  go limit decode path [] = Right (limit, decode, path)
  go limit _ path ("--decode-church" : rest) =
    go limit True path rest
  go _ decode path ("--max-steps" : value : rest) =
    case readMaybe value of
      Just limit | limit > 0 -> go limit decode path rest
      _ -> Left usage
  go limit decode Nothing (value@(first : _) : rest)
    | first /= '-' = go limit decode (Just value) rest
  go _ _ _ _ = Left usage
