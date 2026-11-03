module Main (main) where

import qualified ArithmeticLambda.Par as Arithmetic
import qualified ArithmeticLambda.Print as Arithmetic
import Compiler (compileSource)
import Desugar (desugar, desugarSyntax)
import Graph.Print (printTree)
import qualified PureLambda.Print as Pure
import System.Environment (getArgs)
import System.Exit (die, exitFailure)
import System.IO (hPutStrLn, stderr)

main :: IO ()
main = do
  args <- getArgs
  (mode, path) <- either die pure (parseArgs args)
  source <- maybe getContents readFile path
  let result = case mode of
        Graph -> fmap printTree (compileSource source)
        Desugar -> fmap (Arithmetic.printTree . desugarSyntax) (parseSource source)
        Expand -> fmap (Pure.printTree . desugar) (parseSource source)
  case result of
    Left message -> do
      hPutStrLn stderr ("lambda-to-graph: " ++ message)
      exitFailure
    Right output -> putStrLn output

data Mode = Graph | Desugar | Expand

parseSource source = Arithmetic.pExp (Arithmetic.myLexer source)

parseArgs :: [String] -> Either String (Mode, Maybe FilePath)
parseArgs = go Graph Nothing
 where
  usage = "usage: lambda-to-graph [--desugar | --expand] [FILE]"
  go mode path [] = Right (mode, path)
  go Graph path ("--desugar" : rest) = go Desugar path rest
  go Graph path ("--expand" : rest) = go Expand path rest
  go mode Nothing (value@(first : _) : rest)
    | first /= '-' = go mode (Just value) rest
  go _ _ _ = Left usage
