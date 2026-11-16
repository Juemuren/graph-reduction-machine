{-# LANGUAGE TupleSections #-}

module Main (main) where

import Compiler (
  Reduction (..),
  compileSourceWithEncodings,
  reduceSourceWithEncodings,
 )
import Compiler.Expand (
  Encoding (..),
  Encodings (..),
  ListEncoding (..),
  StringEncoding (..),
  defaultEncodings,
  expandSourceWithEncodings,
 )
import Compiler.ModuleLoader (loadModuleSources)
import Data.List (stripPrefix)
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
            (compileSourceWithEncodings encoding reduction modules sourcePath source)
        Expand ->
          fmap
            Pure.printTree
            (expandSourceWithEncodings encoding modules sourcePath source)
        Reduce ->
          fmap
            Pure.printTree
            (reduceSourceWithEncodings encoding reduction modules sourcePath source)
  case result of
    Left message -> do
      hPutStrLn stderr ("lambda-compiler: " ++ message)
      exitFailure
    Right output -> putStrLn output

data Mode = Graph | Expand | Reduce

parseArgs ::
  [String] -> Either String (Mode, Reduction, Encodings, Maybe FilePath)
parseArgs = go Nothing Nothing Nothing Nothing Nothing
 where
  usage =
    unwords
      [ "usage: lambda-compiler"
      , "[--stop-after=expand|reduce]"
      , "[--enable-reduce=beta|eta|both]"
      , "[--encode-natural=church|scott|binary]"
      , "[--encode-string=church<church|scott|binary>|scott<church|scott|binary>]"
      , "[FILE]"
      ]
  go mode reduction natural string path [] =
    Right
      ( fromMaybe Graph mode
      , fromMaybe NoReduction reduction
      , Encodings
          (fromMaybe Church natural)
          (fromMaybe (stringEncoding defaultEncodings) string)
      , path
      )
  go Nothing reduction natural string path ("--stop-after=expand" : rest) = go (Just Expand) reduction natural string path rest
  go Nothing reduction natural string path ("--stop-after=reduce" : rest) = go (Just Reduce) reduction natural string path rest
  go mode Nothing natural string path ("--enable-reduce=beta" : rest) = go mode (Just BetaOnly) natural string path rest
  go mode Nothing natural string path ("--enable-reduce=eta" : rest) = go mode (Just EtaOnly) natural string path rest
  go mode Nothing natural string path ("--enable-reduce=both" : rest) = go mode (Just BetaEta) natural string path rest
  go mode reduction Nothing string path (value : rest)
    | Just name <- stripPrefix "--encode-natural=" value =
        maybe
          (Left usage)
          (\encoding -> go mode reduction (Just encoding) string path rest)
          (parseNatural name)
  go mode reduction natural Nothing path (value : rest)
    | Just name <- stripPrefix "--encode-string=" value =
        maybe
          (Left usage)
          (\encoding -> go mode reduction natural (Just encoding) path rest)
          (parseString name)
  go mode reduction natural string Nothing (value@(first : _) : rest)
    | first /= '-' = go mode reduction natural string (Just value) rest
  go _ _ _ _ _ _ = Left usage

  parseNatural "church" = Just Church
  parseNatural "scott" = Just Scott
  parseNatural "binary" = Just Binary
  parseNatural _ = Nothing

  parseString name = do
    (list, rest) <- case stripPrefix "church<" name of
      Just value -> Just (ChurchList, value)
      Nothing -> (ScottList,) <$> stripPrefix "scott<" name
    natural <- stripSuffix ">" rest >>= parseNatural
    pure (StringEncoding list natural)

  stripSuffix suffix value = reverse <$> stripPrefix (reverse suffix) (reverse value)
