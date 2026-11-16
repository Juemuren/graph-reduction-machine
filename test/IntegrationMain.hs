module Main (main) where

import Compiler (compileSourceWithEncodings)
import Compiler.Expand (
  Encoding (..),
  Encodings (..),
  ListEncoding (..),
  StringEncoding (..),
  defaultEncodings,
 )
import Control.Monad (void)
import Data.Ratio (denominator, numerator)
import Interpreter (
  DecodeType (..),
  decodeBinaryNatural,
  decodeBoolean,
  decodeComposite,
  decodeInteger,
  decodeNatural,
  decodeRational,
  decodeReal,
  decodeScottNatural,
  interpret,
  parseDecodeType,
 )
import qualified Ski.Abs as Graph
import System.Exit (die)
import TestSupport (
  Expected (..),
  Input (..),
  RunSpec (..),
  TestCase (..),
  assertEqual,
  assertGraph,
  caseLimit,
  normalizeError,
  parseReduction,
  runSuite,
  unwrap,
 )

main :: IO ()
main = runSuite "integration" runCase

runCase :: String -> TestCase -> IO ()
runCase label (TestCase _ (Input language source modules) spec expected) = do
  reduction <- unwrap label (parseReduction (runEnableReduce spec))
  let encoding = case runEncodeNatural spec of
        Just "scott" -> Scott
        Just "binary" -> Binary
        _ -> Church
      selectedStringEncoding = case runEncodeString spec of
        Just "church<church>" -> StringEncoding ChurchList Church
        Just "church<scott>" -> StringEncoding ChurchList Scott
        Just "scott<church>" -> StringEncoding ScottList Church
        Just "scott<scott>" -> StringEncoding ScottList Scott
        Just "scott<binary>" -> StringEncoding ScottList Binary
        _ -> StringEncoding ChurchList Binary
      encodings =
        defaultEncodings
          { naturalEncoding = encoding
          , stringEncoding = selectedStringEncoding
          }
  limit <- caseLimit label 100000 spec
  case (language, runStage spec, expected) of
    ("lambda", "interpret", ExpectedValue graph) ->
      void
        ( assertGraph
            label
            graph
            ( compileSourceWithEncodings encodings reduction modules "<input>" source
                >>= interpret limit
            )
        )
    ("lambda", "decode", _) -> do
      graph <-
        unwrap
          label
          (compileSourceWithEncodings encodings reduction modules "<input>" source)
      let result = decodeGraph spec limit graph
      case expected of
        ExpectedValue value -> unwrap label result >>= assertEqual label value
        ExpectedError problem ->
          case result of
            Left actual -> assertEqual label (normalizeError problem) (normalizeError actual)
            Right _ -> die (label ++ ": expected error " ++ show problem)
    _ -> die (label ++ ": unsupported input, run, or expect combination")

decodeGraph :: RunSpec -> Int -> Graph.Graph -> Either String String
decodeGraph spec limit graph = case runDecode spec of
  Just "natural" -> showDecoded "Natural" show (decodeNatural limit graph)
  Just "scott-natural" -> showScottDecoded (decodeScottNatural limit graph)
  Just "binary-natural" -> showBinaryDecoded (decodeBinaryNatural limit graph)
  Just "boolean" -> showDecoded "Boolean" show (decodeBoolean limit graph)
  Just "integer" -> showDecoded "Integer" show (decodeInteger limit graph)
  Just "rational" -> showDecoded "Rational" renderRational (decodeRational limit graph)
  Just "real" -> do
    index <- maybe (Right 0) Right (runPrecisionReal spec)
    if index < 0
      then Left "precisionReal must be nonnegative"
      else
        showDecoded "Real" renderRational (decodeReal limit (fromInteger index) graph)
  Just name -> case parseDecodeType name of
    Just StringType ->
      showComposite (decodeComposite limit StringType graph)
    Just kind@(EncodedStringType _ _) ->
      showComposite (decodeComposite limit kind graph)
    Just kind@(ListType _) ->
      showComposite (decodeComposite limit kind graph)
    Just kind@(ScottListType _) ->
      showComposite (decodeComposite limit kind graph)
    Just kind@(PairType _ _) ->
      showComposite (decodeComposite limit kind graph)
    _ -> Left "unknown or missing decode type"
  _ -> Left "unknown or missing decode type"
 where
  showDecoded kind render result = do
    value <- result
    maybe (Left ("not a Church " ++ kind)) (Right . render) value
  showScottDecoded result = do
    value <- result
    maybe (Left "not a Scott Natural") (Right . show) value
  showBinaryDecoded result = do
    value <- result
    maybe (Left "not a Binary Natural") (Right . show) value
  showComposite result = do
    value <- result
    maybe (Left "not a value of the requested type") Right value

renderRational :: Rational -> String
renderRational value = show (numerator value) ++ "/" ++ show (denominator value)
