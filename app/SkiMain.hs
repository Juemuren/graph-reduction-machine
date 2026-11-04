module Main (main) where

import Data.Char (toUpper)
import Data.List (stripPrefix)
import Data.Ratio (denominator, numerator)
import Graph.Print (printTree)
import Interpreter (
  decodeBooleanSource,
  decodeIntegerSource,
  decodeNaturalSource,
  decodeRationalSource,
  interpretSource,
 )
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
          Natural ->
            decodeNaturalSource limit source
              >>= maybe (Left "not a Church Natural") (Right . show)
          Boolean ->
            decodeBooleanSource limit source
              >>= maybe (Left "not a Church Boolean") (Right . map toUpper . show)
          Integer ->
            decodeIntegerSource limit source
              >>= maybe (Left "not a Church Integer") (Right . show)
          Rational ->
            decodeRationalSource limit source
              >>= maybe (Left "not a Church Rational") (Right . renderRational)
  case result of
    Left message -> do
      hPutStrLn stderr message
      exitFailure
    Right output -> putStrLn output

renderRational :: Rational -> String
renderRational value = show (numerator value) ++ "/" ++ show (denominator value)

data DecodeMode = Raw | Natural | Boolean | Integer | Rational deriving (Eq)

parseArgs :: [String] -> Either String (Int, DecodeMode, Maybe FilePath)
parseArgs = go 100000 Raw Nothing
 where
  usage =
    unwords
      [ "usage: ski-interpreter"
      , "[--max-steps=N]"
      , "[--decode=natural|boolean|integer|rational]"
      , "[FILE]"
      ]
  go limit mode path [] = Right (limit, mode, path)
  go limit Raw path (value : rest)
    | Just name <- stripPrefix "--decode=" value =
        case name of
          "natural" -> go limit Natural path rest
          "boolean" -> go limit Boolean path rest
          "integer" -> go limit Integer path rest
          "rational" -> go limit Rational path rest
          _ -> Left usage
  go _ mode path (value : rest)
    | Just steps <- stripPrefix "--max-steps=" value =
        case readMaybe steps of
          Just limit | limit > 0 -> go limit mode path rest
          _ -> Left usage
  go limit mode Nothing (value@(first : _) : rest)
    | first /= '-' = go limit mode (Just value) rest
  go _ _ _ _ = Left usage
