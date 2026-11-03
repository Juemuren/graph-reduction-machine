module Main (main) where

import qualified ArithmeticLambda.Abs as Arithmetic
import qualified ArithmeticLambda.Par as Arithmetic
import Compiler (compile, compileSource)
import Desugar (desugar)
import qualified PureLambda.Abs as Pure
import qualified PureLambda.Par as Pure
import System.Exit (die)
import TestSupport (assertExpectedError, assertGraphResult, runCases)

main :: IO ()
main = do
  runCases "test/cases/compiler/compile" ".lambda" ".ski" checkPureGraph
  runCases "test/cases/compiler/syntax" ".lambda" ".parsed.lambda" checkSyntax
  runCases "test/cases/compiler/desugar" ".lambda" ".pure.lambda" checkDesugar
  runCases "test/cases/compiler/errors" ".lambda" ".error" checkError
  putStrLn "compiler tests passed"

parseArithmetic :: FilePath -> String -> IO Arithmetic.Exp
parseArithmetic path source =
  case Arithmetic.pExp (Arithmetic.myLexer source) of
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
  actualExpression <- parseArithmetic sourcePath source
  expectedExpression <- parseArithmetic expectedPath expected
  if actualExpression == expectedExpression
    then putStrLn (sourcePath ++ ": PASS")
    else die (sourcePath ++ ": syntax tree differs from " ++ expectedPath)

checkDesugar :: FilePath -> FilePath -> IO ()
checkDesugar sourcePath expectedPath = do
  source <- readFile sourcePath
  expected <- readFile expectedPath
  expression <- parseArithmetic sourcePath source
  expectedExpression <- parsePure expectedPath expected
  let actualExpression = desugar expression
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
  putStrLn (sourcePath ++ ": PASS")

checkError :: FilePath -> FilePath -> IO ()
checkError sourcePath expectedPath = do
  source <- readFile sourcePath
  assertExpectedError sourcePath expectedPath (compileSource source)
  putStrLn (sourcePath ++ ": PASS")
