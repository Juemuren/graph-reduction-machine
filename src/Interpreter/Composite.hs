-- | Decode typed Church pairs and lists from SKI graphs.
module Interpreter.Composite (
  DecodeType (..),
  parseDecodeType,
  decodeComposite,
  decodeCompositeSourceWithSteps,
) where

import Data.Char (isSpace)
import Data.List (intercalate, stripPrefix)
import Data.Ratio (denominator, numerator)
import Interpreter.Binary (decodeBinaryNaturalAt)
import Interpreter.Church (
  decodeBooleanAt,
  decodeIntegerAt,
  decodeNaturalAt,
  decodePairAt,
  decodeRationalAt,
 )
import Interpreter.Machine
import Interpreter.Scott (decodeScottNaturalAt)
import Numeric.Natural (Natural)
import qualified Ski.Abs as Graph
import qualified Ski.Par as Graph

data DecodeType
  = NaturalType
  | ScottNaturalType
  | BinaryNaturalType
  | BooleanType
  | IntegerType
  | RationalType
  | PairType DecodeType DecodeType
  | ListType DecodeType
  deriving (Eq, Show)

-- | Parse a complete type expression, including nested pairs and lists.
parseDecodeType :: String -> Maybe DecodeType
parseDecodeType source = do
  (value, rest) <- parseType (dropWhile isSpace source)
  if all isSpace rest then Just value else Nothing
 where
  parseType input
    | Just rest <- stripPrefix "list<" input = do
        (elementType, afterElement) <- parseType (dropWhile isSpace rest)
        afterClose <- stripPrefix ">" (dropWhile isSpace afterElement)
        pure (ListType elementType, afterClose)
    | Just rest <- stripPrefix "pair<" input = do
        (firstType, afterFirst) <- parseType (dropWhile isSpace rest)
        afterComma <- stripPrefix "," (dropWhile isSpace afterFirst)
        (secondType, afterSecond) <- parseType (dropWhile isSpace afterComma)
        afterClose <- stripPrefix ">" (dropWhile isSpace afterSecond)
        pure (PairType firstType secondType, afterClose)
    | otherwise = case span
        (\character -> character /= ',' && character /= '>' && not (isSpace character))
        input of
        ("natural", rest) -> Just (NaturalType, rest)
        ("scott-natural", rest) -> Just (ScottNaturalType, rest)
        ("binary-natural", rest) -> Just (BinaryNaturalType, rest)
        ("boolean", rest) -> Just (BooleanType, rest)
        ("integer", rest) -> Just (IntegerType, rest)
        ("rational", rest) -> Just (RationalType, rest)
        _ -> Nothing

decodeComposite ::
  Int -> DecodeType -> Graph.Graph -> Either String (Maybe String)
decodeComposite limit kind graph = runGraph limit graph (decodeAt kind)

decodeCompositeSourceWithSteps ::
  Maybe Int -> DecodeType -> String -> Either String (Maybe String, Natural)
decodeCompositeSourceWithSteps limit kind source =
  Graph.pGraph (Graph.myLexer source) >>= \graph ->
    runGraphWithSteps limit graph (decodeAt kind)

decodeAt :: DecodeType -> Address -> Run (Maybe String)
decodeAt kind root = case kind of
  NaturalType -> fmap (fmap show) (decodeNaturalAt root)
  ScottNaturalType -> fmap (fmap show) (decodeScottNaturalAt root)
  BinaryNaturalType -> fmap (fmap show) (decodeBinaryNaturalAt root)
  BooleanType ->
    fmap (fmap (\value -> if value then "TRUE" else "FALSE")) (decodeBooleanAt root)
  IntegerType -> fmap (fmap show) (decodeIntegerAt root)
  RationalType -> fmap (fmap renderRational) (decodeRationalAt root)
  PairType firstType secondType -> do
    components <- decodePairAt root
    case components of
      Nothing -> pure Nothing
      Just (first, second) -> do
        firstValue <- decodeAt firstType first
        secondValue <- decodeAt secondType second
        pure ((\a b -> "(" ++ a ++ ", " ++ b ++ ")") <$> firstValue <*> secondValue)
  ListType elementType -> do
    cons <- allocate ProbeFunction
    nil <- allocate ProbeValue
    appliedOnce <- allocate (App root cons)
    appliedTwice <- allocate (App appliedOnce nil)
    values <- decodeListAt elementType nil appliedTwice
    pure (fmap (\items -> "[" ++ intercalate ", " items ++ "]") values)

decodeListAt ::
  DecodeType -> Address -> Address -> Run (Maybe [String])
decodeListAt elementType nil current = do
  whnf current
  actual <- resolve current
  if actual == nil
    then pure (Just [])
    else do
      (headNode, applications) <- spine current
      case (headNode, applications) of
        (ProbeFunction, [(_, item), (_, rest)]) -> do
          value <- decodeAt elementType item
          values <- decodeListAt elementType nil rest
          pure ((:) <$> value <*> values)
        _ -> pure Nothing

renderRational :: Rational -> String
renderRational value = show (numerator value) ++ "/" ++ show (denominator value)
