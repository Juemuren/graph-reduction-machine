module Main (main) where

import Compiler (compile, compileSource, reduceSource)
import qualified CoreLambda.Abs as Core
import qualified CoreLambda.Par as Core
import Expand (expand)
import qualified PureLambda.Abs as Pure
import qualified PureLambda.Par as Pure
import System.Exit (ExitCode (ExitSuccess), die)
import System.Process (readProcessWithExitCode)
import TestSupport (
  assertExpectedError,
  assertGraphResult,
  normalizeGraph,
  runCases,
 )

main :: IO ()
main = do
  runCases "test/cases/compiler/compile" ".lambda" ".ski" checkPureGraph
  runCases "test/cases/compiler/reduce" ".lambda" ".reduced.lambda" checkReduce
  runCases
    "test/cases/compiler/reduce-no-beta"
    ".lambda"
    ".reduced.lambda"
    (checkPureOption ["--stop-after=reduce", "--disable-reduce=beta"])
  runCases
    "test/cases/compiler/reduce-no-eta"
    ".lambda"
    ".reduced.lambda"
    (checkPureOption ["--stop-after=reduce", "--disable-reduce=eta"])
  runCases
    "test/cases/compiler/reduce-no-reduce"
    ".lambda"
    ".reduced.lambda"
    (checkPureOption ["--stop-after=reduce", "--disable-reduce=both"])
  runCases
    "test/cases/compiler/compile-no-beta"
    ".lambda"
    ".ski"
    (checkGraphOption ["--disable-reduce=beta"])
  runCases
    "test/cases/compiler/compile-no-eta"
    ".lambda"
    ".ski"
    (checkGraphOption ["--disable-reduce=eta"])
  runCases
    "test/cases/compiler/compile-no-reduce"
    ".lambda"
    ".ski"
    (checkGraphOption ["--disable-reduce=both"])
  runCases "test/cases/compiler/precedence" ".lambda" ".parsed.lambda" checkSyntax
  runCases "test/cases/compiler/encode" ".lambda" ".pure.lambda" checkEncode
  runCases
    "test/cases/compiler/encode"
    ".lambda"
    ".pure.lambda"
    (checkPureOption ["--stop-after=expand"])
  runCases "test/cases/compiler/errors" ".lambda" ".error" checkError
  putStrLn "compiler tests passed"

parseCore :: FilePath -> String -> IO Core.Exp
parseCore path source =
  case Core.pExp (Core.myLexer source) of
    Left problem -> die (path ++ ": " ++ problem)
    Right expression -> pure expression

parsePure :: FilePath -> String -> IO Pure.Exp
parsePure path source =
  case Pure.pExp (Pure.myLexer source) of
    Left problem -> die (path ++ ": " ++ problem)
    Right expression -> pure expression

checkSyntax :: FilePath -> FilePath -> IO ()
checkSyntax sourcePath expectedPath = do
  source <- readFile sourcePath
  expected <- readFile expectedPath
  actualExpression <- parseCore sourcePath source
  expectedExpression <- parseCore expectedPath expected
  if actualExpression == expectedExpression
    then putStrLn (sourcePath ++ ": PASS")
    else die (sourcePath ++ ": syntax tree differs from " ++ expectedPath)

checkEncode :: FilePath -> FilePath -> IO ()
checkEncode sourcePath expectedPath = do
  source <- readFile sourcePath
  expected <- readFile expectedPath
  expression <- parseCore sourcePath source
  expectedExpression <- parsePure expectedPath expected
  let actualExpression = expand expression
  if actualExpression == expectedExpression
    then putStrLn (sourcePath ++ ": PASS")
    else
      die
        ( sourcePath
            ++ ": encoding differs from "
            ++ expectedPath
            ++ "\nexpected:\n"
            ++ show expectedExpression
            ++ "\nactual:\n"
            ++ show actualExpression
        )

checkPureGraph :: FilePath -> FilePath -> IO ()
checkPureGraph sourcePath expectedPath = do
  source <- readFile sourcePath
  expression <- parsePure sourcePath source
  _ <- assertGraphResult sourcePath expectedPath (compile expression)
  checkGraphOption [] sourcePath expectedPath

checkReduce :: FilePath -> FilePath -> IO ()
checkReduce sourcePath expectedPath = do
  source <- readFile sourcePath
  expected <- readFile expectedPath
  expectedExpression <- parsePure expectedPath expected
  case reduceSource source of
    Left problem -> die (sourcePath ++ ": " ++ problem)
    Right actual
      | actual /= expectedExpression ->
          die (sourcePath ++ ": reduced expression differs from " ++ expectedPath)
    Right _ -> pure ()
  checkPureOption ["--stop-after=reduce"] sourcePath expectedPath

checkPureOption :: [String] -> FilePath -> FilePath -> IO ()
checkPureOption options sourcePath expectedPath = do
  output <- runCompiler options sourcePath
  expected <- readFile expectedPath
  actualExpression <- parsePure sourcePath output
  expectedExpression <- parsePure expectedPath expected
  if actualExpression == expectedExpression
    then putStrLn (sourcePath ++ ": PASS")
    else die (sourcePath ++ ": output differs from " ++ expectedPath)

checkGraphOption :: [String] -> FilePath -> FilePath -> IO ()
checkGraphOption options sourcePath expectedPath = do
  output <- runCompiler options sourcePath
  expected <- readFile expectedPath
  if normalizeGraph output == normalizeGraph expected
    then putStrLn (sourcePath ++ ": PASS")
    else
      die
        ( sourcePath
            ++ ": graph differs from "
            ++ expectedPath
            ++ "\nexpected:\n"
            ++ expected
            ++ "\nactual:\n"
            ++ output
        )

runCompiler :: [String] -> FilePath -> IO String
runCompiler options sourcePath = do
  (status, output, problem) <-
    readProcessWithExitCode "lambda-to-graph" (options ++ [sourcePath]) ""
  case status of
    ExitSuccess -> pure output
    _ -> die (sourcePath ++ ": " ++ problem)

checkError :: FilePath -> FilePath -> IO ()
checkError sourcePath expectedPath = do
  source <- readFile sourcePath
  assertExpectedError sourcePath expectedPath (compileSource source)
  putStrLn (sourcePath ++ ": PASS")
