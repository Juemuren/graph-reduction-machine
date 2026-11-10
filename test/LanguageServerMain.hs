{-# LANGUAGE OverloadedStrings #-}

module Main (main) where

import Control.Monad (unless)
import Control.Monad.IO.Class (liftIO)
import Data.Aeson (
  FromJSON,
  Result (..),
  ToJSON,
  Value (..),
  fromJSON,
  object,
  toJSON,
  (.=),
 )
import qualified Data.Aeson.Key as Key
import qualified Data.Aeson.KeyMap as KeyMap
import Data.List (isInfixOf)
import Data.Maybe (isNothing)
import qualified Data.Text as Text
import qualified Data.Text.IO as TextIO
import Language.LSP.Protocol.Message (
  SMethod (SMethod_TextDocumentPrepareRename),
 )
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
    assert
      "named function parameter detail"
      ( any
          ( \item ->
              hasLabel "bar" [item]
                && field "detail" item == Just (String "Parameter of later")
          )
          parameter
      )
    outside <- getCompletions core (Position 4 9)
    assert "parameter scope" (not (hasLabel "bar" outside))
    importedHover <- getHover core (Position 3 25)
    assert "import hover" (maybe False (contains "remote" . show) importedHover)
    standardHover <- getHover core (Position 6 4)
    assert
      "standard library hover"
      ( maybe
          False
          (\hover -> contains "@> ID =" (show hover) && contains "lib" (show hover))
          standardHover
      )
    shadowHover <- getHover core (Position 5 19)
    assert
      "parameter shadow"
      (maybe False (contains "Parameter name" . show) shadowHover)
    semantic <- getSemanticTokens core
    let kinds = case semantic of
          LSP.InL (LSP.SemanticTokens _ values) -> semanticKinds values
          LSP.InR _ -> []
    assert "core semantic tokens" (7 `elem` kinds && 8 `elem` kinds)
    definition <- getDefinitions core (Position 3 17)
    assert "core definition" (locationLine definition == Just 1)
    importedDefinition <- getDefinitions core (Position 3 25)
    assert
      "imported definition"
      ( locationLine importedDefinition == Just 0
          && contains "defs.lambda" (show importedDefinition)
      )
    references <- getReferences core (Position 1 1) True
    assert "core references exclude shadowed parameter" (length references == 2)
    referencesWithoutDeclaration <- getReferences core (Position 1 1) False
    assert
      "core references include definition"
      (length referencesWithoutDeclaration == 2)
    builtinReferences <- getReferences core (Position 6 4) False
    assert "builtin references in current document" (length builtinReferences == 1)
    symbols <- getDocumentSymbols core
    assert
      "core document symbols"
      (contains "later" (show symbols) && contains "name" (show symbols))
    resolved <- getAndResolveCompletions core (Position 3 16)
    assert
      "resolved completion documentation"
      (any (\item -> hasLabel "name" [item] && contains "name =" (show item)) resolved)
    assert
      "function completion shows parameters"
      ( any
          (\item -> hasLabel "name" [item] && field "detail" item == Just (String "x"))
          local
      )
    resolvedParameter <- getAndResolveCompletions core (Position 3 30)
    assert
      "parameter completion has no repeated documentation"
      ( any
          (\item -> hasLabel "bar" [item] && isNothing (field "documentation" item))
          resolvedParameter
      )
    signature <- getSignatureHelp core (Position 3 20) Nothing
    assert "lambda signature" (maybe False (contains "name x" . show) signature)
    signatureDoc <- openDoc "test/cases/lsp/signature.lambda" "core-lambda"
    secondParameter <- getSignatureHelp signatureDoc (Position 1 11) Nothing
    assert
      "second lambda parameter"
      ( case toJSON <$> secondParameter of
          Just (Object fields) -> KeyMap.lookup "activeParameter" fields == Just (Number 1)
          _ -> False
      )
    diagnostics <- getCurrentDiagnostics core
    assert
      "undefined core name diagnostic"
      (any (contains "Undefined name: la" . show) diagnostics)
    commentHover <- getHover core (Position 7 10)
    assert "comment hover" (isNothing commentHover)
    replaceDoc core "main.changed.lambda"
    incomplete <- getCompletions core (Position 2 5)
    assert "incomplete core source" (hasLabel "name" incomplete)
    libraryCompletion <- openDoc "test/cases/lsp/local.lambda" "core-lambda"
    libraryItems <- getCompletions libraryCompletion (Position 1 5)
    assert
      "local completion in expression"
      (hasLabel "SUCC" libraryItems)
    assert
      "local definition takes precedence over standard library"
      ( any
          (\item -> hasLabel "SUCC" [item] && field "detail" item == Just (String "x"))
          libraryItems
      )
    replaceDoc libraryCompletion "local.changed.lambda"
    localHover <- getHover libraryCompletion (Position 1 5)
    assert
      "local hover takes precedence over standard library"
      ( maybe
          False
          (\hover -> contains "SUCC =" (show hover) && not (contains "lib" (show hover)))
          localHover
      )
    standardDoc <- openDoc "test/cases/lsp/standard.lambda" "core-lambda"
    standardItems <- getCompletions standardDoc (Position 0 5)
    assert "standard library completion" (hasLabel "SUCC" standardItems)
    assert
      "standard library parameters"
      ( any
          (\item -> hasLabel "SUCC" [item] && field "detail" item == Just (String "n f x"))
          standardItems
      )
    resolvedStandard <- getAndResolveCompletions standardDoc (Position 0 5)
    assert
      "standard library definition"
      ( any
          (\item -> hasLabel "SUCC" [item] && contains "@> SUCC =" (show item))
          resolvedStandard
      )
    replaceDoc standardDoc "standard.valid.lambda"
    standardIssues <- waitForDiagnostics
    assert "standard library name has no diagnostic" (null standardIssues)
    replaceDoc standardDoc "standard.invalid.lambda"
    missingBuiltinIssues <- waitForDiagnostics
    assert
      "unknown builtin diagnostic"
      (any (contains "Undefined name: NOT_EXPORTED" . show) missingBuiltinIssues)
    topLevel <- openDoc "test/cases/lsp/top-level.lambda" "core-lambda"
    topLevelItems <- getCompletions topLevel (Position 1 1)
    assert
      "implicit entry offers top-level name completion"
      (hasLabel "divMod" topLevelItems)
    anonymous <- openDoc "test/cases/lsp/anonymous.lambda" "core-lambda"
    anonymousItems <- getCompletions anonymous (Position 0 10)
    assert
      "anonymous function parameter detail"
      ( any
          (\item -> hasLabel "x" [item] && field "detail" item == Just (String "Parameter"))
          anonymousItems
      )

    ski <- openDoc "test/cases/lsp/main.ski" "ski-graph"
    nodes <- getCompletions ski (Position 4 6)
    assert "SKI node completion" (all (`hasLabel` nodes) ["#0", "#1", "#2"])
    assert
      "SKI node completion shows body"
      ( any
          (\item -> hasLabel "#0" [item] && field "detail" item == Just (String "#1 #2"))
          nodes
      )
    resolvedNodes <- getAndResolveCompletions ski (Position 4 6)
    assert
      "SKI node completion has documentation"
      ( any
          ( \item ->
              hasLabel "#0" [item]
                && maybe
                  False
                  (contains "```ski-graph\\n#0 = #1 #2;\\n```" . show)
                  (field "documentation" item)
          )
          resolvedNodes
      )
    reference <- getHover ski (Position 0 6)
    assert "SKI reference hover" (maybe False (contains "#1 = I" . show) reference)
    comment <- getHover ski (Position 3 5)
    assert "SKI comment" (isNothing comment)
    replaceDoc ski "main.changed.ski"
    changed <- getHover ski (Position 0 6)
    assert "SKI changed document" (maybe False (contains "#1 = S" . show) changed)

    coreRename <- openDoc "test/cases/lsp/rename.lambda" "core-lambda"
    coreEndReferences <- getReferences coreRename (Position 1 6) False
    assert "core references at name end" (length coreEndReferences == 2)
    coreEndPrepared <-
      request
        SMethod_TextDocumentPrepareRename
        (decodeTest (object ["textDocument" .= coreRename, "position" .= Position 1 6]))
    assert
      "core prepare rename at name end"
      (case toJSON coreEndPrepared of Object _ -> True; _ -> False)
    rename coreRename (Position 1 6) "bar"
    renamedCore <- documentContents coreRename
    expectedCoreRename <- fixture "rename.changed.lambda"
    assert
      "core rename edits declaration and reference"
      (renamedCore == expectedCoreRename)
    upperRename <- openDoc "test/cases/lsp/upper-rename.lambda" "core-lambda"
    prepared <-
      request
        SMethod_TextDocumentPrepareRename
        (decodeTest (object ["textDocument" .= upperRename, "position" .= Position 0 4]))
    assert
      "prepare rename returns a range"
      (case toJSON prepared of Object _ -> True; _ -> False)
    rename upperRename (Position 0 4) "BAR"
    renamedUpper <- documentContents upperRename
    expectedUpperRename <- fixture "upper-rename.changed.lambda"
    assert "uppercase core rename" (renamedUpper == expectedUpperRename)
    unfinishedCore <- openDoc "test/cases/lsp/unfinished.lambda" "core-lambda"
    unfinishedPrepared <-
      request
        SMethod_TextDocumentPrepareRename
        ( decodeTest
            (object ["textDocument" .= unfinishedCore, "position" .= Position 0 3])
        )
    assert
      "unfinished core definition can be renamed"
      (case toJSON unfinishedPrepared of Object _ -> True; _ -> False)
    skiRename <- openDoc "test/cases/lsp/rename.ski" "ski-graph"
    skiDefinition <- getDefinitions skiRename (Position 0 6)
    assert "SKI definition" (locationLine skiDefinition == Just 1)
    skiReferences <- getReferences skiRename (Position 0 6) True
    assert "SKI references" (length skiReferences == 3)
    skiEndReferences <- getReferences skiRename (Position 0 7) False
    assert "SKI references at node end" (length skiEndReferences == 3)
    skiEndPrepared <-
      request
        SMethod_TextDocumentPrepareRename
        (decodeTest (object ["textDocument" .= skiRename, "position" .= Position 0 7]))
    assert
      "SKI prepare rename at node end"
      (case toJSON skiEndPrepared of Object _ -> True; _ -> False)
    skiSymbols <- getDocumentSymbols skiRename
    assert
      "SKI document symbols"
      (contains "#0" (show skiSymbols) && contains "#1" (show skiSymbols))
    rename skiRename (Position 0 7) "2"
    renamedSki <- documentContents skiRename
    expectedSkiRename <- fixture "rename.changed.ski"
    assert "SKI rename edits node and edges" (renamedSki == expectedSkiRename)
    unfinishedSki <- openDoc "test/cases/lsp/unfinished.ski" "ski-graph"
    unfinishedSkiReferences <- getReferences unfinishedSki (Position 1 2) False
    assert
      "unfinished SKI definition keeps references"
      (length unfinishedSkiReferences == 3)

  runSession "graph-reduction-machine-lsp" fullLatestClientCaps root $ do
    missingSemicolon <-
      openDoc "test/cases/lsp/missing-semicolon.lambda" "core-lambda"
    _ <- waitForDiagnostics
    missingSemicolonIssues <- getCurrentDiagnostics missingSemicolon
    assert
      "final entry without semicolon is valid"
      (null missingSemicolonIssues)
    implicitEntry <- openDoc "test/cases/lsp/implicit-entry.lambda" "core-lambda"
    _ <- waitForDiagnostics
    implicitIssues <- getCurrentDiagnostics implicitEntry
    assert "implicit entry without semicolon is valid" (null implicitIssues)
    implicitCompletion <- getCompletions implicitEntry (Position 1 3)
    assert
      "implicit entry offers definition completion"
      (hasLabel "value" implicitCompletion)
    implicitEntrySemi <-
      openDoc "test/cases/lsp/implicit-entry-semicolon.lambda" "core-lambda"
    _ <- waitForDiagnostics
    implicitSemiIssues <- getCurrentDiagnostics implicitEntrySemi
    assert "implicit entry with semicolon is valid" (null implicitSemiIssues)
    finalDefinition <-
      openDoc "test/cases/lsp/final-definition.lambda" "core-lambda"
    _ <- waitForDiagnostics
    finalDefinitionIssues <- getCurrentDiagnostics finalDefinition
    assert
      "final definition still requires semicolon"
      (any (contains "Invalid Core Lambda statement" . show) finalDefinitionIssues)
    invalidMiddle <-
      openDoc "test/cases/lsp/invalid-middle-expression.lambda" "core-lambda"
    _ <- waitForDiagnostics
    middleIssues <- getCurrentDiagnostics invalidMiddle
    assert
      "middle expression without entry marker is invalid"
      (any (contains "Invalid Core Lambda statement" . show) middleIssues)
    entryFirst <- openDoc "test/cases/lsp/entry-first.lambda" "core-lambda"
    _ <- waitForDiagnostics
    firstEntryIssues <- getCurrentDiagnostics entryFirst
    assert "entry before definitions is valid" (null firstEntryIssues)
    entryMiddle <- openDoc "test/cases/lsp/entry-middle.lambda" "core-lambda"
    _ <- waitForDiagnostics
    middleEntryIssues <- getCurrentDiagnostics entryMiddle
    assert "entry between definitions is valid" (null middleEntryIssues)
    _ <- openDoc "test/cases/lsp/invalid.lambda" "core-lambda"
    coreIssues <- waitForDiagnostics
    assert
      "core syntax diagnostic"
      (any (contains "Invalid Core Lambda statement" . show) coreIssues)
    invalidCore <- openDoc "test/cases/lsp/changed.lambda" "core-lambda"
    _ <- waitForDiagnostics
    insertion <- Text.stripEnd <$> fixture "changed.insert.lambda"
    changeDoc
      invalidCore
      [changeAt (LSP.Range (Position 0 7) (Position 0 7)) insertion]
    updatedCoreIssues <- waitForDiagnostics
    assert "incremental change clears core diagnostic" (null updatedCoreIssues)
    invalidSki <- openDoc "test/cases/lsp/invalid.ski" "ski-graph"
    skiIssues <- waitForDiagnostics
    assert
      "SKI undefined node diagnostic"
      (any (contains "Undefined node: #2" . show) skiIssues)
    assert
      "SKI duplicate node diagnostic"
      (any (contains "Duplicate node: #1" . show) skiIssues)
    replaceDoc invalidSki "invalid.changed.ski"
    cleared <- waitForDiagnostics
    assert "diagnostics update after change" (null cleared)
    replaceDoc invalidSki "invalid.unfinished.ski"
    unfinishedSkiIssues <- waitForDiagnostics
    assert
      "unfinished SKI statement diagnostic"
      (any (contains "Invalid SKI node definition" . show) unfinishedSkiIssues)

assert :: String -> Bool -> Session ()
assert label passed = liftIO $ unless passed (die ("language server test failed: " ++ label))

fixture :: FilePath -> Session Text.Text
fixture name = liftIO $ TextIO.readFile ("test/cases/lsp/" ++ name)

replaceDoc document name = do
  source <- fixture name
  changeDoc document [change source]

hasLabel :: (ToJSON a) => String -> [a] -> Bool
hasLabel label = any $ \item -> case toJSON item of
  Object fields -> KeyMap.lookup "label" fields == Just (String (Text.pack label))
  _ -> False

field :: (ToJSON a) => Text.Text -> a -> Maybe Value
field name item = case toJSON item of
  Object fields -> KeyMap.lookup (Key.fromText name) fields
  _ -> Nothing

decodeTest :: (FromJSON a) => Value -> a
decodeTest value = case fromJSON value of
  Success result -> result
  Error message -> error message

locationLine :: (ToJSON a) => a -> Maybe Int
locationLine value = case toJSON value of
  Object location -> do
    Object range <- KeyMap.lookup "range" location
    Object start <- KeyMap.lookup "start" range
    KeyMap.lookup "line" start >>= decodedInt
  _ -> Nothing

decodedInt :: Value -> Maybe Int
decodedInt value = case fromJSON value of
  Success number -> Just number
  Error _ -> Nothing

contains :: String -> String -> Bool
contains = isInfixOf

change :: Text.Text -> TextDocumentContentChangeEvent
change source = case fromJSON (object ["text" .= source]) of
  Success result -> result
  Error message -> error message

changeAt :: LSP.Range -> Text.Text -> TextDocumentContentChangeEvent
changeAt range source = case fromJSON (object ["range" .= range, "text" .= source]) of
  Success result -> result
  Error message -> error message

semanticKinds :: [a] -> [a]
semanticKinds (_ : _ : _ : kind : _ : rest) = kind : semanticKinds rest
semanticKinds _ = []
