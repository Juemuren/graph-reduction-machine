module Main (main) where

import Compiler (Reduction (..), compileSourceWith, reduceSourceWith)
import qualified CoreLambda.Par as Core
import Data.Maybe (fromMaybe)
import Expand (expand)
import Graph.Print (printTree)
import qualified PureLambda.Print as Pure
import System.Environment (getArgs)
import System.Exit (die, exitFailure)
import System.IO (hPutStrLn, stderr)

main :: IO ()
main = do
  args <- getArgs
  (mode, reduction, path) <- either die pure (parseArgs args)
  source <- maybe getContents readFile path
  let result = case mode of
        Graph -> fmap printTree (compileSourceWith reduction source)
        Expand -> fmap (Pure.printTree . expand) (parseSource source)
        Reduce -> fmap Pure.printTree (reduceSourceWith reduction source)
  case result of
    Left message -> do
      hPutStrLn stderr ("lambda-to-graph: " ++ message)
      exitFailure
    Right output -> putStrLn output

data Mode = Graph | Expand | Reduce

parseSource source = Core.pExp (Core.myLexer source)

parseArgs :: [String] -> Either String (Mode, Reduction, Maybe FilePath)
parseArgs = go Nothing Nothing Nothing
 where
  usage =
    unwords
    [
      "usage: lambda-to-graph"
    , "[--stop-after=expand|reduce]"
    , "[--disable-reduce=beta|eta|both]"
    , "[FILE]"
    ]
  go mode reduction path [] = Right (fromMaybe Graph mode, fromMaybe BetaEta reduction, path)
  go Nothing reduction path ("--stop-after=expand" : rest) = go (Just Expand) reduction path rest
  go Nothing reduction path ("--stop-after=reduce" : rest) = go (Just Reduce) reduction path rest
  go mode Nothing path ("--disable-reduce=beta" : rest) = go mode (Just EtaOnly) path rest
  go mode Nothing path ("--disable-reduce=eta" : rest) = go mode (Just BetaOnly) path rest
  go mode Nothing path ("--disable-reduce=both" : rest) = go mode (Just NoReduction) path rest
  go mode reduction Nothing (value@(first : _) : rest)
    | first /= '-' = go mode reduction (Just value) rest
  go _ _ _ _ = Left usage
