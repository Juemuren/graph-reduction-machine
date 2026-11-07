-- | Decode Church-encoded values from SKI graphs.
module Interpreter.Church (
  decodeNaturalSource,
  decodeNaturalSourceWithSteps,
  decodeNatural,
  decodeBooleanSource,
  decodeBooleanSourceWithSteps,
  decodeBoolean,
  decodeIntegerSource,
  decodeIntegerSourceWithSteps,
  decodeInteger,
  decodeRationalSource,
  decodeRationalSourceWithSteps,
  decodeRational,
  decodeRealSource,
  decodeRealSourceWithSteps,
  decodeReal,
) where

import Data.Ratio ((%))
import Interpreter.Machine
import Numeric.Natural (Natural)
import qualified Ski.Abs as Graph
import qualified Ski.Par as Graph

-- | Apply a closed SKI term to symbolic f and x, then recognize f^n x.
decodeNaturalSource :: Int -> String -> Either String (Maybe Natural)
decodeNaturalSource limit source = fst <$> decodeNaturalSourceWithSteps (Just limit) source

decodeNaturalSourceWithSteps ::
  Maybe Int -> String -> Either String (Maybe Natural, Natural)
decodeNaturalSourceWithSteps limit source =
  Graph.pGraph (Graph.myLexer source) >>= \graph -> runGraphWithSteps limit graph decodeNaturalAt

decodeNatural :: Int -> Graph.Graph -> Either String (Maybe Natural)
decodeNatural limit graph = runGraph limit graph decodeNaturalAt

-- | Decode a Church integer represented by a pair of Church naturals.
decodeIntegerSource :: Int -> String -> Either String (Maybe Integer)
decodeIntegerSource limit source = fst <$> decodeIntegerSourceWithSteps (Just limit) source

decodeIntegerSourceWithSteps ::
  Maybe Int -> String -> Either String (Maybe Integer, Natural)
decodeIntegerSourceWithSteps limit source =
  Graph.pGraph (Graph.myLexer source) >>= \graph -> runGraphWithSteps limit graph decodeIntegerAt

decodeInteger :: Int -> Graph.Graph -> Either String (Maybe Integer)
decodeInteger limit graph = runGraph limit graph decodeIntegerAt

decodeIntegerAt :: Address -> Run (Maybe Integer)
decodeIntegerAt root = do
  components <- decodePairAt root
  case components of
    Nothing -> pure Nothing
    Just (positive, negative) -> do
      first <- decodeNaturalAt positive
      second <- decodeNaturalAt negative
      pure ((\a b -> toInteger a - toInteger b) <$> first <*> second)

-- | Decode a pair of Church integers as a reduced rational number.
decodeRationalSource :: Int -> String -> Either String (Maybe Rational)
decodeRationalSource limit source = fst <$> decodeRationalSourceWithSteps (Just limit) source

decodeRationalSourceWithSteps ::
  Maybe Int -> String -> Either String (Maybe Rational, Natural)
decodeRationalSourceWithSteps limit source =
  Graph.pGraph (Graph.myLexer source) >>= \graph -> runGraphWithSteps limit graph decodeRationalAt

decodeRational :: Int -> Graph.Graph -> Either String (Maybe Rational)
decodeRational limit graph = runGraph limit graph decodeRationalAt

decodeRationalAt :: Address -> Run (Maybe Rational)
decodeRationalAt root = do
  components <- decodePairAt root
  case components of
    Nothing -> pure Nothing
    Just (numerator, denominator) -> do
      first <- decodeIntegerAt numerator
      second <- decodeIntegerAt denominator
      pure $ case (first, second) of
        (Just a, Just b) | b /= 0 -> Just (a % b)
        _ -> Nothing

-- | Decode the rational approximation at the given natural index.
decodeRealSource :: Int -> Natural -> String -> Either String (Maybe Rational)
decodeRealSource limit precision source = fst <$> decodeRealSourceWithSteps (Just limit) precision source

decodeRealSourceWithSteps ::
  Maybe Int -> Natural -> String -> Either String (Maybe Rational, Natural)
decodeRealSourceWithSteps limit precision source =
  Graph.pGraph (Graph.myLexer source) >>= \graph ->
    runGraphWithSteps limit graph $ \root -> do
      index <- allocate (ChurchNumeral precision)
      approximation <- allocate (App root index)
      decodeRationalAt approximation

decodeReal :: Int -> Natural -> Graph.Graph -> Either String (Maybe Rational)
decodeReal limit precision graph =
  runGraph limit graph $ \root -> do
    index <- allocate (ChurchNumeral precision)
    approximation <- allocate (App root index)
    decodeRationalAt approximation

decodePairAt :: Address -> Run (Maybe (Address, Address))
decodePairAt root = do
  selector <- allocate ProbeFunction
  selected <- allocate (App root selector)
  whnf selected
  (headNode, applications) <- spine selected
  pure $ case (headNode, applications) of
    (ProbeFunction, [(_, first), (_, second)]) -> Just (first, second)
    _ -> Nothing

decodeNaturalAt :: Address -> Run (Maybe Natural)
decodeNaturalAt root = do
  function <- allocate ProbeFunction
  value <- allocate ProbeValue
  appliedOnce <- allocate (App root function)
  appliedTwice <- allocate (App appliedOnce value)
  normalize appliedTwice
  countApplications function value appliedTwice 0

-- | Apply a closed SKI term to two distinct symbolic values and identify the selected one.
decodeBooleanSource :: Int -> String -> Either String (Maybe Bool)
decodeBooleanSource limit source = fst <$> decodeBooleanSourceWithSteps (Just limit) source

decodeBooleanSourceWithSteps ::
  Maybe Int -> String -> Either String (Maybe Bool, Natural)
decodeBooleanSourceWithSteps limit source =
  Graph.pGraph (Graph.myLexer source) >>= \graph ->
    runGraphWithSteps limit graph decodeBooleanAt

decodeBoolean :: Int -> Graph.Graph -> Either String (Maybe Bool)
decodeBoolean limit graph = runGraph limit graph decodeBooleanAt

decodeBooleanAt :: Address -> Run (Maybe Bool)
decodeBooleanAt root = do
  trueValue <- allocate ProbeFunction
  falseValue <- allocate ProbeValue
  appliedOnce <- allocate (App root trueValue)
  appliedTwice <- allocate (App appliedOnce falseValue)
  normalize appliedTwice
  result <- resolve appliedTwice
  pure $
    if result == trueValue
      then Just True
      else if result == falseValue then Just False else Nothing

countApplications ::
  Address -> Address -> Address -> Natural -> Run (Maybe Natural)
countApplications function value address count = do
  actual <- resolve address
  if actual == value
    then pure (Just count)
    else do
      node <- readNode actual
      case node of
        App headAddress argument -> do
          actualHead <- resolve headAddress
          if actualHead == function
            then countApplications function value argument (count + 1)
            else pure Nothing
        _ -> pure Nothing
