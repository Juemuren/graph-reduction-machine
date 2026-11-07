{-# LANGUAGE OverloadedStrings #-}

module TestSupport (
  TestCase (..),
  CliCase (..),
  Input (..),
  RunSpec (..),
  Expected (..),
  runSuite,
  runCliSuite,
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
  Value (..),
  eitherDecode,
  fromJSON,
  withObject,
  (.:),
  (.:?),
 )
import Data.Aeson.Types (Parser)
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

newtype CaseFile a = CaseFile [a]

data TestCase = TestCase String Input RunSpec Expected

data CliCase = CliCase String String [String] String Int String String

data Input = Input String String (Map.Map FilePath String)

data RunSpec = RunSpec
  { runStage :: String
  , runDecode :: Maybe String
  , runPrecisionReal :: Maybe Integer
  , runMaxSteps :: Maybe Int
  , runEnableReduce :: Maybe String
  }

data Expected
  = ExpectedValue String
  | ExpectedError String

instance (FromJSON a) => FromJSON (CaseFile a) where
  parseJSON = withObject "case file" $ \object -> CaseFile <$> object .: "cases"

instance FromJSON TestCase where
  parseJSON = withObject "test case" $ \object -> do
    name <- object .: "name"
    input <- parseJSON (Object object)
    stage <- object .: "stage"
    options <- object .:? "options"
    spec <-
      maybe
        (pure (RunSpec stage Nothing Nothing Nothing Nothing))
        (parseRunSpec stage)
        options
    TestCase name input spec <$> object .: "expect"

instance FromJSON CliCase where
  parseJSON = withObject "CLI test case" $ \object -> do
    name <- object .: "name"
    command <- object .: "command"
    args <- object .: "args"
    stdin <- object .: "stdin"
    expected <- object .: "expect"
    withObject
      "CLI expectation"
      ( \value ->
          CliCase name command args stdin
            <$> value .: "exitCode"
            <*> value .: "stdout"
            <*> value .: "stderr"
      )
      expected

instance FromJSON Input where
  parseJSON = withObject "input" $ \object ->
    Input
      <$> object .: "language"
      <*> object .: "source"
      <*> (fromMaybe Map.empty <$> object .:? "modules")

parseRunSpec :: String -> Value -> Parser RunSpec
parseRunSpec stage = withObject "options" $ \object ->
  RunSpec stage
    <$> object .:? "decode"
    <*> object .:? "precisionReal"
    <*> object .:? "maxSteps"
    <*> object .:? "enableReduce"

instance FromJSON Expected where
  parseJSON = withObject "expect" $ \object -> do
    value <- object .:? "value"
    problem <- object .:? "error"
    case catMaybes [ExpectedValue <$> value, ExpectedError <$> problem] of
      [expected] -> pure expected
      _ -> fail "expect must contain exactly one of value or error"

runSuite :: String -> (String -> TestCase -> IO ()) -> IO ()
runSuite suiteName = runSuiteWith suiteName "test/cases/language.schema.json" caseName
 where
  caseName (TestCase name _ _ _) = name

runCliSuite :: (String -> CliCase -> IO ()) -> IO ()
runCliSuite = runSuiteWith "cli" "test/cases/cli.schema.json" caseName
 where
  caseName (CliCase name _ _ _ _ _ _) = name

runSuiteWith ::
  (FromJSON a) =>
  String -> FilePath -> (a -> String) -> (String -> a -> IO ()) -> IO ()
runSuiteWith suiteName schemaPath caseName runCase = do
  let root = "test/cases" </> suiteName
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
    let names = map caseName cases
    when (length names /= length (nub names)) $
      die (path ++ ": case names must be unique")
    forM_ cases $ \testCase -> do
      let label = path ++ ":" ++ caseName testCase
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
parseReduction Nothing = Right NoReduction
parseReduction (Just "beta") = Right BetaOnly
parseReduction (Just "eta") = Right EtaOnly
parseReduction (Just "both") = Right BetaEta
parseReduction (Just value) = Left ("unknown enableReduce: " ++ value)

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
