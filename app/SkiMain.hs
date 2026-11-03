module Main (main) where

import Data.Char (toUpper)
import Graph.Print (printTree)
import Interpreter (decodeBooleanSource, decodeChurchSource, interpretSource)
import System.Environment (getArgs)
import System.Exit (die, exitFailure)
import System.IO (hPutStrLn, stderr)
import Text.Read (readMaybe)

main :: IO ()
main = do
  args <- getArgs
  (limit, mode, path) <- either die pure (parseArgs args)
  source <- maybe getContents readFile path
  let result =
        case mode of
          Raw -> fmap printTree (interpretSource limit source)
          Number ->
            decodeChurchSource limit source
              >>= maybe (Left "not a Church Number") (Right . show)
          Boolean ->
            decodeBooleanSource limit source
              >>= maybe (Left "not a Church Boolean") (Right . map toUpper . show)
  case result of
    Left message -> do
      hPutStrLn stderr message
      exitFailure
    Right output -> putStrLn output

data DecodeMode = Raw | Number | Boolean deriving (Eq)

parseArgs :: [String] -> Either String (Int, DecodeMode, Maybe FilePath)
parseArgs = go 100000 Raw Nothing
 where
  usage = "usage: ski-interpreter [--max-steps N] [--decode-number | --decode-boolean] [FILE]"
  go limit mode path [] = Right (limit, mode, path)
  go limit Raw path ("--decode-number" : rest) =
    go limit Number path rest
  go limit Raw path ("--decode-boolean" : rest) =
    go limit Boolean path rest
  go _ mode path ("--max-steps" : value : rest) =
    case readMaybe value of
      Just limit | limit > 0 -> go limit mode path rest
      _ -> Left usage
  go limit mode Nothing (value@(first : _) : rest)
    | first /= '-' = go limit mode (Just value) rest
  go _ _ _ _ = Left usage
