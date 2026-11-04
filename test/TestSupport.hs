{-# LANGUAGE OverloadedStrings #-}

module TestSupport (
  TestCase (..),
  Input (..),
  RunSpec (..),
  Expected (..),
  runSuite,
  caseLimit,
  parseReduction,
  assertGraph,
  assertError,
  assertEqual,
  unwrap,
  normalizeGraph,
  normalizeError,
)
where

import Compiler (Reduction (..))
import Control.Monad (forM_, unless, when)
import Data.Aeson (
  FromJSON (..),
  Result (..),
  Value,
  eitherDecode,
  fromJSON,
  withObject,
  (.:),
  (.:?),
 )
import qualified Data.ByteString.Lazy as ByteString
import Data.JSON.JSONSchema (validate)
import Data.List (nub, sort)
import qualified Data.Map.Strict as Map
import Data.Maybe (catMaybes, fromMaybe, isJust)
import qualified Ski.Abs as Graph
import Ski.Print (printTree)
import System.Directory (doesDirectoryExist, listDirectory)
import System.Exit (die)
import System.FilePath (takeExtension, (</>))

newtype CaseFile = CaseFile [TestCase]

data TestCase = TestCase String Input RunSpec Expected

data Input = Input String String (Map.Map FilePath String)

data RunSpec = RunSpec
  { runStage :: String
  , runDecode :: Maybe String
  , runPrecisionReal :: Maybe Integer
  , runMaxSteps :: Maybe Int
  , runDisableReduce :: Maybe String
  }

data Expected = ExpectedGraph String | ExpectedValue String | ExpectedError String

instance FromJSON CaseFile where
  parseJSON = withObject "case file" $ \object -> CaseFile <$> object .: "cases"

instance FromJSON TestCase where
  parseJSON = withObject "test case" $ \object ->
    TestCase
      <$> object .: "name"
      <*> object .: "input"
      <*> object .: "run"
      <*> object .: "expect"

instance FromJSON Input where
  parseJSON = withObject "input" $ \object ->
    Input
      <$> object .: "language"
      <*> object .: "source"
      <*> (fromMaybe Map.empty <$> object .:? "modules")

instance FromJSON RunSpec where
  parseJSON = withObject "run" $ \object ->
    RunSpec
      <$> object .: "stage"
      <*> object .:? "type"
      <*> object .:? "precisionReal"
      <*> object .:? "maxSteps"
      <*> object .:? "disableReduce"

instance FromJSON Expected where
  parseJSON = withObject "expect" $ \object -> do
    graph <- object .:? "graph"
    value <- object .:? "value"
    problem <- object .:? "error"
    case catMaybes
      [ExpectedGraph <$> graph, ExpectedValue <$> value, ExpectedError <$> problem] of
      [expected] -> pure expected
      _ -> fail "expect must contain exactly one of graph, value, or error"

runSuite :: String -> (String -> TestCase -> IO ()) -> IO ()
runSuite suiteName runCase = do
  let schemaPath = "test/cases/schema.json"
      root = "test/cases" </> suiteName
  schemaBytes <- ByteString.readFile schemaPath
  schema <- unwrap schemaPath (eitherDecode schemaBytes :: Either String Value)
  entries <- sort <$> listDirectory root
  paths <- concat <$> mapM (jsonFiles . (root </>)) entries
  when (null paths) $ die ("no JSON cases in " ++ root)
  forM_ paths $ \path -> do
    bytes <- ByteString.readFile path
    fixture <- unwrap path (eitherDecode bytes :: Either String Value)
    case validate schema fixture of
      Left problems ->
        die
          (path ++ ": JSON Schema validation failed:\n" ++ unlines (map show problems))
      Right () -> pure ()
    CaseFile cases <- case fromJSON fixture of
      Error problem -> die (path ++ ": " ++ problem)
      Success result -> pure result
    when (null cases) $ die (path ++ ": empty cases array")
    let names = [name | TestCase name _ _ _ <- cases]
    when (length names /= length (nub names)) $
      die (path ++ ": case names must be unique")
    forM_ cases $ \testCase@(TestCase name _ _ _) -> do
      let label = path ++ ":" ++ name
      runCase label testCase
      putStrLn (label ++ ": PASS")
  putStrLn (suiteName ++ " tests passed")
 where
  jsonFiles path = do
    directory <- doesDirectoryExist path
    if directory
      then do
        names <- listDirectory path
        pure (sort [path </> name | name <- names, takeExtension name == ".json"])
      else pure [path | takeExtension path == ".json"]

caseLimit :: String -> Int -> RunSpec -> IO Int
caseLimit label defaultLimit spec = do
  let limit = fromMaybe defaultLimit (runMaxSteps spec)
  when (limit <= 0) $ die (label ++ ": maxSteps must be positive")
  when (maybe False (< 0) (runPrecisionReal spec)) $
    die (label ++ ": precisionReal must be nonnegative")
  when (isJust (runPrecisionReal spec) && runDecode spec /= Just "real") $
    die (label ++ ": precisionReal requires real decoding")
  pure limit

parseReduction :: Maybe String -> Either String Reduction
parseReduction Nothing = Right BetaEta
parseReduction (Just "beta") = Right EtaOnly
parseReduction (Just "eta") = Right BetaOnly
parseReduction (Just "both") = Right NoReduction
parseReduction (Just value) = Left ("unknown disableReduce: " ++ value)

assertGraph :: String -> String -> Either String Graph.Graph -> IO String
assertGraph label expected result = do
  graph <- unwrap label result
  let actual = printTree graph
  assertEqual label (normalizeGraph expected) (normalizeGraph actual)
  pure actual

assertError :: String -> String -> Either String a -> IO ()
assertError label expected result =
  case result of
    Left actual -> assertEqual label (normalizeError expected) (normalizeError actual)
    Right _ -> die (label ++ ": expected error " ++ show expected)

assertEqual :: (Eq a, Show a) => String -> a -> a -> IO ()
assertEqual label expected actual =
  unless (expected == actual) $
    die (label ++ ": expected " ++ show expected ++ ", got " ++ show actual)

unwrap :: String -> Either String a -> IO a
unwrap label = either (\problem -> die (label ++ ": " ++ problem)) pure

normalizeGraph :: String -> [String]
normalizeGraph = lines . filter (/= '\r')

normalizeError :: String -> String
normalizeError = reverse . dropWhile (== '\n') . reverse . filter (/= '\r')
