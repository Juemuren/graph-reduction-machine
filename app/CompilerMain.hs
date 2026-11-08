module Main (main) where

import Compiler (
  Reduction (..),
  compileSourceWithModules,
  reduceSourceWithModules,
 )
import Compiler.Expand (expandSource)
import Compiler.ModuleLoader (loadModuleSources)
import Data.Maybe (fromMaybe)
import qualified PureLambda.Print as Pure
import Ski.Print (printTree)
import System.Environment (getArgs)
import System.Exit (die, exitFailure)
import System.IO (hPutStrLn, stderr)

main :: IO ()
main = do
  args <- getArgs
  (mode, reduction, path) <- either die pure (parseArgs args)
  source <- maybe getContents readFile path
  modules <-
    loadModuleSources (fromMaybe "<input>" path) source >>= either die pure
  let sourcePath = fromMaybe "<input>" path
  let result = case mode of
        Graph ->
          fmap printTree (compileSourceWithModules reduction modules sourcePath source)
        Expand -> fmap Pure.printTree (expandSource modules sourcePath source)
        Reduce ->
          fmap
            Pure.printTree
            (reduceSourceWithModules reduction modules sourcePath source)
  case result of
    Left message -> do
      hPutStrLn stderr ("lambda-compiler: " ++ message)
      exitFailure
    Right output -> putStrLn output

data Mode = Graph | Expand | Reduce

parseArgs :: [String] -> Either String (Mode, Reduction, Maybe FilePath)
parseArgs = go Nothing Nothing Nothing
 where
  usage =
    unwords
      [ "usage: lambda-compiler"
      , "[--stop-after=expand|reduce]"
      , "[--enable-reduce=beta|eta|both]"
      , "[FILE]"
      ]
  go mode reduction path [] = Right (fromMaybe Graph mode, fromMaybe NoReduction reduction, path)
  go Nothing reduction path ("--stop-after=expand" : rest) = go (Just Expand) reduction path rest
  go Nothing reduction path ("--stop-after=reduce" : rest) = go (Just Reduce) reduction path rest
  go mode Nothing path ("--enable-reduce=beta" : rest) = go mode (Just BetaOnly) path rest
  go mode Nothing path ("--enable-reduce=eta" : rest) = go mode (Just EtaOnly) path rest
  go mode Nothing path ("--enable-reduce=both" : rest) = go mode (Just BetaEta) path rest
  go mode reduction Nothing (value@(first : _) : rest)
    | first /= '-' = go mode reduction (Just value) rest
  go _ _ _ _ = Left usage
