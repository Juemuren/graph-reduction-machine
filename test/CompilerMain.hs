module Main (main) where

import Compiler (
  compile,
  compileSourceWithEncoding,
  reduceSource,
  reduceSourceWithEncoding,
 )
import Compiler.Expand (Encoding (..), expandSourceWith)
import Control.Monad (void, when)
import qualified CoreLambda.Par as Core
import qualified Data.Map.Strict as Map
import qualified PureLambda.Abs as Pure
import qualified PureLambda.Par as Pure
import System.Exit (ExitCode (..), die)
import System.Process (readProcessWithExitCode)
import TestSupport (
  Expected (..),
  Input (..),
  RunSpec (..),
  TestCase (..),
  assertEqual,
  assertError,
  assertGraph,
  caseLimit,
  normalizeGraph,
  parseReduction,
  runSuite,
  unwrap,
 )

main :: IO ()
main = runSuite "compiler" runCase

runCase :: String -> TestCase -> IO ()
runCase label (TestCase _ (Input language source modules) spec expected) = do
  void (caseLimit label 100000 spec)
  reduction <- unwrap label (parseReduction (runEnableReduce spec))
  let encoding = if runEncode spec == Just "scott" then Scott else Church
  case (language, runStage spec, expected) of
    ("lambda", "parse", ExpectedValue value) ->
      assertParsed label source value
    ("lambda", "parse", ExpectedError problem) ->
      assertError label problem (Core.pExp (Core.myLexer source))
    ("lambda", "expand", ExpectedValue value) ->
      assertReduced
        label
        value
        (expandSourceWith encoding modules "<input>" (asProgram source))
    ("lambda", "reduce", ExpectedValue value) ->
      if Map.null modules
        then do
          when (runEnableReduce spec == Just "both") $
            assertReduced label value (reduceSource (asProgram source))
          output <- runCompiler label (compilerOptions "reduce" spec) source
          assertReduced label value (Pure.pExp (Pure.myLexer output))
        else
          assertReduced
            label
            value
            (reduceSourceWithEncoding encoding reduction modules "<input>" source)
    ("lambda", "compile", ExpectedValue graph) ->
      if Map.null modules
        then do
          when (runEnableReduce spec == Just "both") $ do
            expression <- unwrap label (Pure.pExp (Pure.myLexer source))
            void (assertGraph label graph (compile expression))
          output <- runCompiler label (compilerOptions "compile" spec) source
          assertEqual label (normalizeGraph graph) (normalizeGraph output)
        else
          void
            ( assertGraph
                label
                graph
                (compileSourceWithEncoding encoding reduction modules "<input>" source)
            )
    ("lambda", "compile", ExpectedError problem) ->
      assertError
        label
        problem
        ( compileSourceWithEncoding
            encoding
            reduction
            modules
            "<input>"
            (asProgram source)
        )
    _ -> die (label ++ ": unsupported input, run, or expect combination")

compilerOptions :: String -> RunSpec -> [String]
compilerOptions stage spec =
  ["--stop-after=reduce" | stage == "reduce"]
    ++ maybe [] (\value -> ["--enable-reduce=" ++ value]) (runEnableReduce spec)
    ++ maybe [] (\value -> ["--encode=" ++ value]) (runEncode spec)

runCompiler :: String -> [String] -> String -> IO String
runCompiler label options source = do
  let program = asProgram source
  (status, output, problem) <-
    readProcessWithExitCode "lambda-compiler" options program
  case status of
    ExitSuccess -> pure output
    _ -> die (label ++ ": " ++ problem)

asProgram :: String -> String
asProgram source
  | any (`elem` ("@=;" :: String)) source = source
  | otherwise = "@! " ++ source ++ ";"

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
