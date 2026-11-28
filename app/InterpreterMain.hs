module Main (main) where

import Control.Monad (when)
import Data.Bifunctor (first)
import Data.Char (toUpper)
import Data.List (stripPrefix)
import Data.Maybe (fromMaybe, isNothing)
import Data.Ratio (denominator, numerator)
import Interpreter (
  DecodeType (..),
  ShareMode (..),
  decodeBinaryNaturalSourceWithSteps,
  decodeBooleanSourceWithSteps,
  decodeCompositeSourceWithSteps,
  decodeIntegerSourceWithSteps,
  decodeNaturalSourceWithSteps,
  decodeRationalSourceWithSteps,
  decodeRealSourceWithSteps,
  decodeScottNaturalSourceWithSteps,
  interpretSourceWithShareWithSteps,
  parseDecodeType,
  renderGraphviz,
  renderMermaid,
 )
import Numeric.Natural (Natural)
import qualified Ski.Abs as Graph
import Ski.Print (printTree)
import System.Environment (getArgs)
import System.Exit (die, exitFailure)
import System.IO (hPutStrLn, stderr)
import Text.Read (readMaybe)

main :: IO ()
main = do
  args <- getArgs
  (limit, showSteps, mode, sharing, outputFormat, path) <-
    either die pure (parseArgs args)
  source <- maybe getContents readFile path
  let result =
        case mode of
          Raw ->
            first (renderOutput outputFormat)
              <$> interpretSourceWithShareWithSteps sharing limit source
          Natural ->
            decodeNaturalSourceWithSteps limit source
              >>= renderDecoded "not a Church Natural" show
          ScottNatural ->
            decodeScottNaturalSourceWithSteps limit source
              >>= renderDecoded "not a Scott Natural" show
          BinaryNatural ->
            decodeBinaryNaturalSourceWithSteps limit source
              >>= renderDecoded "not a Binary Natural" show
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
          Composite kind ->
            decodeCompositeSourceWithSteps limit kind source
              >>= renderDecoded "not a value of the requested type" id
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

data OutputFormat = Ski | Graphviz | Mermaid deriving (Eq)

renderOutput :: OutputFormat -> Graph.Graph -> String
renderOutput format graph = case format of
  Ski -> printTree graph
  Graphviz -> renderGraphviz graph
  Mermaid -> renderMermaid graph

data DecodeMode
  = Raw
  | Natural
  | ScottNatural
  | BinaryNatural
  | Boolean
  | Integer
  | Rational
  | Real Natural
  | Composite DecodeType
  deriving (Eq)

parseArgs ::
  [String] ->
  Either
    String
    (Maybe Int, Bool, DecodeMode, ShareMode, OutputFormat, Maybe FilePath)
parseArgs = go Nothing False Raw Nothing Nothing Nothing
 where
  usage =
    unwords
      [ "usage: ski-interpreter"
      , "[--max-steps=N|0|infty]"
      , "[--show-steps]"
      , "[--share=preserve|merge|unfold]"
      , "[--output=ski|graphviz|mermaid]"
      , "[--decode=natural|scott-natural|binary-natural|boolean|integer|rational|real|real:N|string|string:L<N>|list<T>|scott-list<T>|pair<A,B>]"
      , "[FILE]"
      ]
  go limit showSteps mode sharing output path [] = case (mode, sharing, output) of
    (Raw, _, _) ->
      Right
        ( fromMaybe (Just 100000) limit
        , showSteps
        , Raw
        , fromMaybe Preserve sharing
        , fromMaybe Ski output
        , path
        )
    (_, Nothing, Nothing) -> Right (fromMaybe (Just 100000) limit, showSteps, mode, Preserve, Ski, path)
    _ -> Left usage
  go limit showSteps Raw Nothing Nothing path (value : rest)
    | Just name <- stripPrefix "--decode=" value =
        case name of
          "natural" -> go limit showSteps Natural Nothing Nothing path rest
          "scott-natural" -> go limit showSteps ScottNatural Nothing Nothing path rest
          "binary-natural" -> go limit showSteps BinaryNatural Nothing Nothing path rest
          "boolean" -> go limit showSteps Boolean Nothing Nothing path rest
          "integer" -> go limit showSteps Integer Nothing Nothing path rest
          "rational" -> go limit showSteps Rational Nothing Nothing path rest
          "string" ->
            go limit showSteps (Composite StringType) Nothing Nothing path rest
          _ ->
            maybe
              (Left usage)
              (\selected -> go limit showSteps selected Nothing Nothing path rest)
              (parseTypedMode name)
  go limit showSteps Raw Nothing output path (value : rest)
    | Just name <- stripPrefix "--share=" value =
        case name of
          "preserve" -> go limit showSteps Raw (Just Preserve) output path rest
          "merge" -> go limit showSteps Raw (Just Merge) output path rest
          "unfold" -> go limit showSteps Raw (Just Unfold) output path rest
          _ -> Left usage
  go limit showSteps Raw sharing Nothing path (value : rest)
    | Just name <- stripPrefix "--output=" value =
        case name of
          "ski" -> go limit showSteps Raw sharing (Just Ski) path rest
          "graphviz" -> go limit showSteps Raw sharing (Just Graphviz) path rest
          "mermaid" -> go limit showSteps Raw sharing (Just Mermaid) path rest
          _ -> Left usage
  go limit showSteps mode sharing output path (value : rest)
    | value == "--show-steps" && not showSteps =
        go limit True mode sharing output path rest
  go limit showSteps mode sharing output path (value : rest)
    | value == "--max-steps=infty" && isNothing limit =
        go (Just Nothing) showSteps mode sharing output path rest
    | Just steps <- stripPrefix "--max-steps=" value =
        case readMaybe steps of
          Just maximumSteps
            | maximumSteps >= 0 && limit /= Just Nothing ->
                go (Just (Just maximumSteps)) showSteps mode sharing output path rest
          _ -> Left usage
  go limit showSteps mode sharing output Nothing (value@(first : _) : rest)
    | first /= '-' =
        go limit showSteps mode sharing output (Just value) rest
  go _ _ _ _ _ _ _ = Left usage

  parseTypedMode name = case parseDecodeType name of
    Just (RealType index) -> Just (Real index)
    Just kind@(ListType _) -> Just (Composite kind)
    Just kind@(ScottListType _) -> Just (Composite kind)
    Just kind@(PairType _ _) -> Just (Composite kind)
    Just kind@(EncodedStringType _ _) -> Just (Composite kind)
    _ -> Nothing
