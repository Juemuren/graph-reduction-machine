module Main (main) where

import Data.Char (toUpper)
import Data.List (stripPrefix)
import Data.Ratio (denominator, numerator)
import Interpreter (
  decodeBooleanSource,
  decodeIntegerSource,
  decodeNaturalSource,
  decodeRationalSource,
  decodeRealSource,
  interpretSource,
 )
import Numeric.Natural (Natural)
import Ski.Print (printTree)
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
          Real precision ->
            decodeRealSource limit precision source
              >>= maybe (Left "not a Church Real") (Right . renderRational)
  case result of
    Left message -> do
      hPutStrLn stderr message
      exitFailure
    Right output -> putStrLn output

renderRational :: Rational -> String
renderRational value = show (numerator value) ++ "/" ++ show (denominator value)

data DecodeMode = Raw | Natural | Boolean | Integer | Rational | Real Natural
  deriving (Eq)

parseArgs :: [String] -> Either String (Int, DecodeMode, Maybe FilePath)
parseArgs = go 100000 Raw Nothing Nothing
 where
  usage =
    unwords
      [ "usage: ski-interpreter"
      , "[--max-steps=N]"
      , "[--decode=natural|boolean|integer|rational|real]"
      , "[--precision-real=N]"
      , "[FILE]"
      ]
  go limit mode precision path [] = case (mode, precision) of
    (Real _, Just index) -> Right (limit, Real index, path)
    (Real _, Nothing) -> Right (limit, Real 0, path)
    (_, Nothing) -> Right (limit, mode, path)
    _ -> Left usage
  go limit Raw precision path (value : rest)
    | Just name <- stripPrefix "--decode=" value =
        case name of
          "natural" -> go limit Natural precision path rest
          "boolean" -> go limit Boolean precision path rest
          "integer" -> go limit Integer precision path rest
          "rational" -> go limit Rational precision path rest
          "real" -> go limit (Real 0) precision path rest
          _ -> Left usage
  go _ mode precision path (value : rest)
    | Just steps <- stripPrefix "--max-steps=" value =
        case readMaybe steps of
          Just limit | limit > 0 -> go limit mode precision path rest
          _ -> Left usage
  go limit mode Nothing path (value : rest)
    | Just index <- stripPrefix "--precision-real=" value =
        case readMaybe index :: Maybe Integer of
          Just precision | precision >= 0 -> go limit mode (Just (fromInteger precision)) path rest
          _ -> Left usage
  go limit mode precision Nothing (value@(first : _) : rest)
    | first /= '-' = go limit mode precision (Just value) rest
  go _ _ _ _ _ = Left usage
