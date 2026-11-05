{-# LANGUAGE OverloadedStrings #-}

module Main (main) where

import Control.Monad (unless)
import Control.Monad.IO.Class (liftIO)
import Data.Aeson (
  Result (..),
  ToJSON,
  Value (..),
  fromJSON,
  object,
  toJSON,
  (.=),
 )
import qualified Data.Aeson.KeyMap as KeyMap
import Data.List (isInfixOf)
import Data.Maybe (isNothing)
import qualified Data.Text as Text
import Language.LSP.Protocol.Types (
  Position (..),
  TextDocumentContentChangeEvent,
 )
import qualified Language.LSP.Protocol.Types as LSP
import Language.LSP.Test
import System.Directory (getCurrentDirectory)
import System.Exit (die)

main :: IO ()
main = do
  root <- getCurrentDirectory
  runSession "graph-reduction-machine-lsp" fullLatestClientCaps root $ do
    core <- openDoc "test/cases/lsp/main.lambda" "core-lambda"
    imported <- getCompletions core (Position 3 22)
    assert "core import completion" (hasLabel "remote" imported)
    local <- getCompletions core (Position 3 16)
    assert "core local completion" (hasLabel "name" local)
    parameter <- getCompletions core (Position 3 30)
    assert "parameter completion" (hasLabel "bar" parameter)
    outside <- getCompletions core (Position 4 9)
    assert "parameter scope" (not (hasLabel "bar" outside))
    importedHover <- getHover core (Position 3 25)
    assert "import hover" (maybe False (contains "remote" . show) importedHover)
    shadowHover <- getHover core (Position 5 19)
    assert
      "parameter shadow"
      (maybe False (contains "Parameter name" . show) shadowHover)
    semantic <- getSemanticTokens core
    let kinds = case semantic of
          LSP.InL (LSP.SemanticTokens _ values) -> semanticKinds values
          LSP.InR _ -> []
    assert "core semantic tokens" (7 `elem` kinds && 8 `elem` kinds)
    commentHover <- getHover core (Position 7 10)
    assert "comment hover" (isNothing commentHover)
    changeDoc
      core
      [change "@< \"./defs.lambda\" (remote);\nname = \\x -> x;\n@! na"]
    incomplete <- getCompletions core (Position 2 5)
    assert "incomplete core source" (hasLabel "name" incomplete)

    ski <- openDoc "test/cases/lsp/main.ski" "ski-graph"
    nodes <- getCompletions ski (Position 4 6)
    assert "SKI node completion" (all (`hasLabel` nodes) ["#0", "#1", "#2"])
    reference <- getHover ski (Position 0 6)
    assert "SKI reference hover" (maybe False (contains "#1 = I" . show) reference)
    comment <- getHover ski (Position 3 5)
    assert "SKI comment" (isNothing comment)
    changeDoc ski [change "#0 = #1 #2;\n#1 = S;\n#2 = K;\n#3 = #"]
    changed <- getHover ski (Position 0 6)
    assert "SKI changed document" (maybe False (contains "#1 = S" . show) changed)

assert :: String -> Bool -> Session ()
assert label passed = liftIO $ unless passed (die ("language server test failed: " ++ label))

hasLabel :: (ToJSON a) => String -> [a] -> Bool
hasLabel label = any $ \item -> case toJSON item of
  Object fields -> KeyMap.lookup "label" fields == Just (String (Text.pack label))
  _ -> False

contains :: String -> String -> Bool
contains = isInfixOf

change :: Text.Text -> TextDocumentContentChangeEvent
change source = case fromJSON (object ["text" .= source]) of
  Success result -> result
  Error message -> error message

semanticKinds :: [a] -> [a]
semanticKinds (_ : _ : _ : kind : _ : rest) = kind : semanticKinds rest
semanticKinds _ = []
