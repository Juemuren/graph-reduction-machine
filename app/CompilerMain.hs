module Main (main) where

import Compiler (
  Reduction (..),
  compileSourceWithEncoding,
  reduceSourceWithEncoding,
 )
import Compiler.Expand (Encoding (..), expandSourceWith)
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
  (mode, reduction, encoding, path) <- either die pure (parseArgs args)
  source <- maybe getContents readFile path
  modules <-
    loadModuleSources (fromMaybe "<input>" path) source >>= either die pure
  let sourcePath = fromMaybe "<input>" path
  let result = case mode of
        Graph ->
          fmap
            printTree
            (compileSourceWithEncoding encoding reduction modules sourcePath source)
        Expand -> fmap Pure.printTree (expandSourceWith encoding modules sourcePath source)
        Reduce ->
          fmap
            Pure.printTree
            (reduceSourceWithEncoding encoding reduction modules sourcePath source)
  case result of
    Left message -> do
      hPutStrLn stderr ("lambda-compiler: " ++ message)
      exitFailure
    Right output -> putStrLn output

data Mode = Graph | Expand | Reduce

parseArgs ::
  [String] -> Either String (Mode, Reduction, Encoding, Maybe FilePath)
parseArgs = go Nothing Nothing Nothing Nothing
 where
  usage =
    unwords
      [ "usage: lambda-compiler"
      , "[--stop-after=expand|reduce]"
      , "[--enable-reduce=beta|eta|both]"
      , "[--encode=church|scott]"
      , "[FILE]"
      ]
  go mode reduction encoding path [] =
    Right
      ( fromMaybe Graph mode
      , fromMaybe NoReduction reduction
      , fromMaybe Church encoding
      , path
      )
  go Nothing reduction encoding path ("--stop-after=expand" : rest) = go (Just Expand) reduction encoding path rest
  go Nothing reduction encoding path ("--stop-after=reduce" : rest) = go (Just Reduce) reduction encoding path rest
  go mode Nothing encoding path ("--enable-reduce=beta" : rest) = go mode (Just BetaOnly) encoding path rest
  go mode Nothing encoding path ("--enable-reduce=eta" : rest) = go mode (Just EtaOnly) encoding path rest
  go mode Nothing encoding path ("--enable-reduce=both" : rest) = go mode (Just BetaEta) encoding path rest
  go mode reduction Nothing path ("--encode=church" : rest) = go mode reduction (Just Church) path rest
  go mode reduction Nothing path ("--encode=scott" : rest) = go mode reduction (Just Scott) path rest
  go mode reduction encoding Nothing (value@(first : _) : rest)
    | first /= '-' = go mode reduction encoding (Just value) rest
  go _ _ _ _ _ = Left usage
