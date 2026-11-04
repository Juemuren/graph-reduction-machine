{-# LANGUAGE OverloadedStrings #-}

module TestSupport (Suite (..), runSuite) where

import Compiler (Reduction (..), compile, compileSourceWith, reduceSource)
import Control.Monad (forM_, unless, void, when)
import qualified CoreLambda.Par as Core
import Data.Aeson (FromJSON (..), Result (..), Value, eitherDecode, fromJSON, withObject, (.:), (.:?))
import qualified Data.ByteString.Lazy as ByteString
import Data.JSON.JSONSchema (validate)
import Data.List (nub, sort)
import Data.Maybe (catMaybes, fromMaybe, isJust, isNothing)
import Data.Ratio (denominator, numerator)
import qualified Graph.Abs as Graph
import Graph.Print (printTree)
import Interpreter (
  decodeBoolean,
  decodeInteger,
  decodeNatural,
  decodeRational,
  decodeReal,
  interpret,
  interpretSource,
 )
import qualified PureLambda.Abs as Pure
import qualified PureLambda.Par as Pure
import System.Directory (listDirectory)
import System.Exit (ExitCode (..), die)
import System.FilePath (takeExtension, (</>))
import System.Process (readProcessWithExitCode)

data Suite = CompilerSuite | InterpreterSuite | IntegrationSuite

newtype CaseFile = CaseFile [TestCase]

data TestCase = TestCase String Input RunSpec Expected

data Input = Input String String

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
    Input <$> object .: "language" <*> object .: "source"

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

runSuite :: Suite -> IO ()
runSuite suite = do
  let schemaPath = "test/cases/schema.json"
      root = "test/cases" </> suiteName suite
  schemaBytes <- ByteString.readFile schemaPath
  schema <- unwrap schemaPath (eitherDecode schemaBytes :: Either String Value)
  directories <- sort <$> listDirectory root
  paths <- concat <$> mapM (jsonFiles . (root </>)) directories
  when (null paths) $ die ("no JSON cases in " ++ root)
  forM_ paths $ \path -> do
    bytes <- ByteString.readFile path
    fixture <- unwrap path (eitherDecode bytes :: Either String Value)
    case validate schema fixture of
      Left problems -> die (path ++ ": JSON Schema validation failed:\n" ++ unlines (map show problems))
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
      runCase suite label testCase
      putStrLn (label ++ ": PASS")
  putStrLn (suiteName suite ++ " tests passed")
 where
  jsonFiles directory = do
    names <- listDirectory directory
    pure (sort [directory </> name | name <- names, takeExtension name == ".json"])

suiteName :: Suite -> String
suiteName CompilerSuite = "compiler"
suiteName InterpreterSuite = "interpreter"
suiteName IntegrationSuite = "integration"

runCase :: Suite -> String -> TestCase -> IO ()
runCase suite label (TestCase _ (Input language source) spec expected) = do
  reduction <- unwrap label (parseReduction (runDisableReduce spec))
  let defaultLimit =
        if suiteName suite == "interpreter" && runStage spec == "interpret"
          then 100
          else 100000
      limit = fromMaybe defaultLimit (runMaxSteps spec)
  when (limit <= 0) $ die (label ++ ": maxSteps must be positive")
  when (maybe False (< 0) (runPrecisionReal spec)) $
    die (label ++ ": precisionReal must be nonnegative")
  when (isJust (runPrecisionReal spec) && runDecode spec /= Just "real") $
    die (label ++ ": precisionReal requires real decoding")
  case (suite, language, runStage spec, expected) of
    (CompilerSuite, "lambda", "parse", ExpectedValue value) ->
      assertParsed label source value
    (CompilerSuite, "lambda", "reduce", ExpectedValue value) -> do
      when (isNothing (runDisableReduce spec)) $
        assertReduced label value (reduceSource source)
      output <- runCompiler label (compilerOptions "reduce" spec) source
      assertReduced label value (Pure.pExp (Pure.myLexer output))
    (CompilerSuite, "lambda", "compile", ExpectedGraph graph) -> do
      when (isNothing (runDisableReduce spec)) $ do
        expression <- unwrap label (Pure.pExp (Pure.myLexer source))
        void (assertGraph label graph (compile expression))
      output <- runCompiler label (compilerOptions "compile" spec) source
      assertEqual label (normalizeGraph graph) (normalizeGraph output)
    (CompilerSuite, "lambda", "compile", ExpectedError problem) ->
      assertError label problem (compileSourceWith reduction source)
    (InterpreterSuite, "ski", "interpret", ExpectedGraph graph) -> do
      actual <- assertGraph label graph (interpretSource limit source)
      again <- unwrap label (interpretSource limit actual)
      assertEqual label (normalizeGraph actual) (normalizeGraph (printTree again))
    (InterpreterSuite, "ski", "interpret", ExpectedError problem) ->
      assertError label problem (interpretSource limit source)
    (InterpreterSuite, "ski", "decode", ExpectedError problem) ->
      assertDecodeCliError label source spec limit problem
    (IntegrationSuite, "lambda", "undecode", ExpectedGraph graph) ->
      void
        (assertGraph label graph (compileSourceWith reduction source >>= interpret limit))
    (IntegrationSuite, "lambda", "decode", _) -> do
      graph <- unwrap label (compileSourceWith reduction source)
      let result = decodeGraph spec limit graph
      case expected of
        ExpectedValue value -> unwrap label result >>= assertEqual label value
        ExpectedError problem ->
          case result of
            Left actual -> assertEqual label (normalizeError problem) (normalizeError actual)
            Right _ -> die (label ++ ": expected error " ++ show problem)
        _ -> die (label ++ ": decode requires value or error expectation")
    _ -> die (label ++ ": unsupported input, run, or expect combination")

parseReduction :: Maybe String -> Either String Reduction
parseReduction Nothing = Right BetaEta
parseReduction (Just "beta") = Right EtaOnly
parseReduction (Just "eta") = Right BetaOnly
parseReduction (Just "both") = Right NoReduction
parseReduction (Just value) = Left ("unknown disableReduce: " ++ value)

compilerOptions :: String -> RunSpec -> [String]
compilerOptions stage spec =
  ["--stop-after=reduce" | stage == "reduce"]
    ++ maybe [] (\value -> ["--disable-reduce=" ++ value]) (runDisableReduce spec)

runCompiler :: String -> [String] -> String -> IO String
runCompiler label options source = do
  (status, output, problem) <-
    readProcessWithExitCode "lambda-to-graph" options source
  case status of
    ExitSuccess -> pure output
    _ -> die (label ++ ": " ++ problem)

assertDecodeCliError :: String -> String -> RunSpec -> Int -> String -> IO ()
assertDecodeCliError label source spec limit expected = do
  decodeType <-
    maybe (die (label ++ ": decode type is required")) pure (runDecode spec)
  let options =
        ["--max-steps=" ++ show limit, "--decode=" ++ decodeType]
          ++ maybe [] (\index -> ["--precision-real=" ++ show index]) (runPrecisionReal spec)
  (status, output, problem) <-
    readProcessWithExitCode "ski-interpreter" options source
  unless (status == ExitFailure 1 && null output) $
    die
      ( label
          ++ ": expected exit 1 and empty stdout, got "
          ++ show (status, output, problem)
      )
  assertEqual label (normalizeError expected) (normalizeError problem)

decodeGraph :: RunSpec -> Int -> Graph.Graph -> Either String String
decodeGraph spec limit graph = case runDecode spec of
  Just "natural" -> showDecoded "Natural" show (decodeNatural limit graph)
  Just "boolean" -> showDecoded "Boolean" show (decodeBoolean limit graph)
  Just "integer" -> showDecoded "Integer" show (decodeInteger limit graph)
  Just "rational" -> showDecoded "Rational" renderRational (decodeRational limit graph)
  Just "real" -> do
    index <- maybe (Right 0) Right (runPrecisionReal spec)
    if index < 0
      then Left "precisionReal must be nonnegative"
      else
        showDecoded "Real" renderRational (decodeReal limit (fromInteger index) graph)
  _ -> Left "unknown or missing decode type"
 where
  showDecoded kind render result = do
    value <- result
    maybe (Left ("not a Church " ++ kind)) (Right . render) value

renderRational :: Rational -> String
renderRational value = show (numerator value) ++ "/" ++ show (denominator value)

assertParsed :: String -> String -> String -> IO ()
assertParsed label source expected = do
  actual <- unwrap label (Core.pExp (Core.myLexer source))
  wanted <- unwrap label (Core.pExp (Core.myLexer expected))
  assertEqual label wanted actual

assertReduced :: String -> String -> Either String Pure.Exp -> IO ()
assertReduced label expected result = do
  actual <- unwrap label result
  wanted <- unwrap label (Pure.pExp (Pure.myLexer expected))
  assertEqual label wanted actual

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
