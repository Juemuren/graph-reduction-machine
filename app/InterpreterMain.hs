module Main (main) where

import Control.Monad (when)
import Data.Bifunctor (first)
import Data.Char (toUpper)
import Data.List (stripPrefix)
import Data.Maybe (fromMaybe, isNothing)
import Data.Ratio (denominator, numerator)
import Interpreter (
  decodeBooleanSourceWithSteps,
  decodeIntegerSourceWithSteps,
  decodeNaturalSourceWithSteps,
  decodeRationalSourceWithSteps,
  decodeRealSourceWithSteps,
  interpretSourceWithSteps,
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
  (limit, showSteps, mode, path) <- either die pure (parseArgs args)
  source <- maybe getContents readFile path
  let result =
        case mode of
          Raw -> first printTree <$> interpretSourceWithSteps limit source
          Natural ->
            decodeNaturalSourceWithSteps limit source
              >>= renderDecoded "not a Church Natural" show
          Boolean ->
            decodeBooleanSourceWithSteps limit source
              >>= renderDecoded "not a Church Boolean" (map toUpper . show)
          Integer ->
            decodeIntegerSourceWithSteps limit source
              >>= renderDecoded "not a Church Integer" show
          Rational ->
            decodeRationalSourceWithSteps limit source
              >>= renderDecoded "not a Church Rational" renderRational
          Real precision ->
            decodeRealSourceWithSteps limit precision source
              >>= renderDecoded "not a Church Real" renderRational
  case result of
    Left message -> do
      hPutStrLn stderr message
      exitFailure
    Right (output, steps) -> do
      putStrLn output
      when showSteps $ hPutStrLn stderr ("steps: " ++ show steps)

renderDecoded ::
  String -> (a -> String) -> (Maybe a, Natural) -> Either String (String, Natural)
renderDecoded message render (value, steps) =
  maybe (Left message) (\result -> Right (render result, steps)) value

renderRational :: Rational -> String
renderRational value = show (numerator value) ++ "/" ++ show (denominator value)

data DecodeMode = Raw | Natural | Boolean | Integer | Rational | Real Natural
  deriving (Eq)

parseArgs ::
  [String] -> Either String (Maybe Int, Bool, DecodeMode, Maybe FilePath)
parseArgs = go Nothing False Raw Nothing Nothing
 where
  usage =
    unwords
      [ "usage: ski-interpreter"
      , "[--max-steps=N|--no-step-limit]"
      , "[--show-steps]"
      , "[--decode=natural|boolean|integer|rational|real]"
      , "[--precision-real=N]"
      , "[FILE]"
      ]
  go limit showSteps mode precision path [] = case (mode, precision) of
    (Real _, Just index) -> Right (fromMaybe (Just 100000) limit, showSteps, Real index, path)
    (Real _, Nothing) -> Right (fromMaybe (Just 100000) limit, showSteps, Real 0, path)
    (_, Nothing) -> Right (fromMaybe (Just 100000) limit, showSteps, mode, path)
    _ -> Left usage
  go limit showSteps Raw precision path (value : rest)
    | Just name <- stripPrefix "--decode=" value =
        case name of
          "natural" -> go limit showSteps Natural precision path rest
          "boolean" -> go limit showSteps Boolean precision path rest
          "integer" -> go limit showSteps Integer precision path rest
          "rational" -> go limit showSteps Rational precision path rest
          "real" -> go limit showSteps (Real 0) precision path rest
          _ -> Left usage
  go limit showSteps mode precision path (value : rest)
    | value == "--no-step-limit" && isNothing limit =
        go (Just Nothing) showSteps mode precision path rest
  go limit showSteps mode precision path (value : rest)
    | value == "--show-steps" && not showSteps =
        go limit True mode precision path rest
  go limit showSteps mode precision path (value : rest)
    | Just steps <- stripPrefix "--max-steps=" value =
        case readMaybe steps of
          Just maximumSteps
            | maximumSteps > 0 && limit /= Just Nothing ->
                go (Just (Just maximumSteps)) showSteps mode precision path rest
          _ -> Left usage
  go limit showSteps mode Nothing path (value : rest)
    | Just index <- stripPrefix "--precision-real=" value =
        case readMaybe index :: Maybe Integer of
          Just precision
            | precision >= 0 ->
                go limit showSteps mode (Just (fromInteger precision)) path rest
          _ -> Left usage
  go limit showSteps mode precision Nothing (value@(first : _) : rest)
    | first /= '-' = go limit showSteps mode precision (Just value) rest
  go _ _ _ _ _ _ = Left usage
