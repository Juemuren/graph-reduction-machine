module Main (main) where

import qualified ArithmeticLambda.Abs as Arithmetic
import qualified ArithmeticLambda.Par as Arithmetic
import Compiler (compileSource)
import Data.List (isInfixOf, isSuffixOf, sort)
import Desugar (desugar)
import Graph.Print (printTree)
import qualified PureLambda.Abs as Pure
import qualified PureLambda.Par as Pure
import System.Directory (listDirectory)
import System.Exit (die)
import System.FilePath ((</>), dropExtension, takeExtension)

main :: IO ()
main = do
  runCases "test/cases/valid" ".ski" checkGraph
  runCases "test/cases/errors" ".error" checkError
  runCases "test/cases/syntax" ".parsed.lambda" checkSyntax
  runCases "test/cases/desugar" ".pure.lambda" checkDesugar
  putStrLn "compiler tests passed"

runCases :: FilePath -> String -> (FilePath -> FilePath -> IO ()) -> IO ()
runCases directory expectedSuffix check = do
  entries <- listDirectory directory
  let sources = sort
        [ directory </> name
        | name <- entries
        , takeExtension name == ".lambda"
        , not (expectedSuffix `isSuffixOf` name)
        ]
  if null sources then die ("no test cases in " ++ directory) else pure ()
  mapM_ (\source -> check source (dropExtension source ++ expectedSuffix)) sources

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
    else die (sourcePath ++ ": Church encoding differs from " ++ expectedPath
              ++ "\nexpected:\n" ++ show expectedExpression
              ++ "\nactual:\n" ++ show actualExpression)

checkGraph :: FilePath -> FilePath -> IO ()
checkGraph sourcePath expectedPath = do
  source <- readFile sourcePath
  expected <- readFile expectedPath
  case compileSource source of
    Left problem -> die (sourcePath ++ ": " ++ problem)
    Right graph -> do
      let actual = printTree graph
      if normalize actual == normalize expected
        then putStrLn (sourcePath ++ ": PASS")
        else die (sourcePath ++ ": graph differs from " ++ expectedPath
                  ++ "\nexpected:\n" ++ expected ++ "\nactual:\n" ++ actual)

checkError :: FilePath -> FilePath -> IO ()
checkError sourcePath expectedPath = do
  source <- readFile sourcePath
  expected <- readFile expectedPath
  case compileSource source of
    Left problem ->
      if not (null (trim expected)) && trim expected `isInfixOf` problem
        then putStrLn (sourcePath ++ ": PASS")
        else die (sourcePath ++ ": expected error containing " ++ show (trim expected)
                  ++ ", got " ++ show problem)
    Right _ -> die (sourcePath ++ ": expected compilation to fail")

-- Ignore platform line endings and a final newline in golden files.
normalize :: String -> [String]
normalize = lines . filter (/= '\r')

trim :: String -> String
trim = unwords . words
