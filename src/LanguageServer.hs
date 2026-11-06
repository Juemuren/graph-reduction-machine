{-# LANGUAGE OverloadedStrings #-}

module LanguageServer (runLanguageServer) where

import Control.Exception (IOException, evaluate, try)
import Control.Monad (guard)
import Control.Monad.IO.Class (liftIO)
import Data.Aeson (
  FromJSON,
  Result (..),
  Value (..),
  fromJSON,
  object,
  toJSON,
  (.=),
 )
import qualified Data.Aeson.Key as Key
import qualified Data.Aeson.KeyMap as KeyMap
import Data.Char (isAlphaNum, isAsciiLower, isAsciiUpper, isDigit)
import Data.Maybe (fromMaybe)
import qualified Data.Text as Text
import Language.LSP.Protocol.Message
import qualified Language.LSP.Protocol.Types as LSP
import Language.LSP.Server
import Language.LSP.VFS (virtualFileLanguageKind, virtualFileText)
import LanguageServer.Common (
  Completion (..),
  Hover (..),
  Position (..),
  Range (..),
  Symbol (..),
  offsetAt,
  slice,
 )
import LanguageServer.Lambda (
  coreCanRename,
  coreCompletions,
  coreDiagnostics,
  coreDocumentSymbols,
  coreHover,
  coreImportAt,
  coreReferencesAt,
  coreSemanticTokens,
  coreSignatureHelp,
  coreSymbolAt,
  exportedDefinition,
  exportedDefinitionRange,
 )
import LanguageServer.Ski (
  skiCanRename,
  skiCompletions,
  skiDiagnostics,
  skiDocumentSymbols,
  skiHover,
  skiSymbolAt,
 )
import System.FilePath (normalise, takeDirectory, takeExtension, (</>))

runLanguageServer :: IO Int
runLanguageServer =
  runServer
    ServerDefinition
      { parseConfig = const $ const $ Right ()
      , onConfigChange = const $ pure ()
      , defaultConfig = ()
      , configSection = "graph-reduction-machine"
      , doInitialize = \env _ -> pure $ Right env
      , staticHandlers = const handlers
      , interpretHandler = \env -> Iso (runLspT env) liftIO
      , options =
          defaultOptions
            { optTextDocumentSync =
                Just
                  ( LSP.TextDocumentSyncOptions
                      (Just True)
                      (Just LSP.TextDocumentSyncKind_Incremental)
                      Nothing
                      Nothing
                      Nothing
                  )
            , optCompletionTriggerCharacters = Just ['#']
            , optSignatureHelpTriggerCharacters = Just [' ']
            }
      }

handlers :: Handlers (LspM ())
handlers =
  mconcat
    [ notificationHandler SMethod_Initialized $ \_ -> pure ()
    , notificationHandler SMethod_WorkspaceDidChangeConfiguration $ \_ -> pure ()
    , notificationHandler SMethod_TextDocumentDidOpen $ \(TNotificationMessage _ _ params) -> publishOpened (toJSON params)
    , notificationHandler SMethod_TextDocumentDidChange $ \(TNotificationMessage _ _ params) -> publishFor (toJSON params)
    , notificationHandler SMethod_TextDocumentDidClose $ \(TNotificationMessage _ _ params) ->
        case uriOf (toJSON params) of
          Nothing -> pure ()
          Just uri -> publishEditorDiagnostics uri []
    , requestHandler SMethod_TextDocumentCompletion $ \(TRequestMessage _ _ _ params) respond -> do
        items <- withDocument (toJSON params) $ \language source _ ->
          pure $ case language of
            "core-lambda" -> coreCompletions source (positionOf (toJSON params))
            "ski-graph" -> skiCompletions source (positionOf (toJSON params))
            _ -> []
        respond $
          Right $
            LSP.InL (maybe [] (map (decodeResult . completionValue)) items)
    , requestHandler SMethod_CompletionItemResolve $ \(TRequestMessage _ _ _ item) respond ->
        respond $ Right $ decodeResult (resolvedCompletionValue (toJSON item))
    , requestHandler SMethod_TextDocumentHover $ \(TRequestMessage _ _ _ params) respond -> do
        result <- withDocument (toJSON params) $ \language source uri -> case language of
          "core-lambda" -> liftIO $ resolveCoreHover uri source (positionOf (toJSON params))
          "ski-graph" -> pure (skiHover source (positionOf (toJSON params)))
          _ -> pure Nothing
        respond $
          Right $
            maybe
              (LSP.InR LSP.Null)
              (LSP.InL . decodeResult . hoverValue)
              (joinMaybe result)
    , requestHandler SMethod_TextDocumentSemanticTokensFull $ \(TRequestMessage _ _ _ params) respond -> do
        result <- withDocument (toJSON params) $ \language source _ ->
          pure $
            if language == "core-lambda"
              then Just (semanticValue (coreSemanticTokens source))
              else Nothing
        respond $
          Right $
            maybe (LSP.InR LSP.Null) (LSP.InL . decodeResult) (joinMaybe result)
    , requestHandler SMethod_TextDocumentDefinition $ \(TRequestMessage _ _ _ params) respond -> do
        result <- withDocument (toJSON params) $ \language source uri ->
          liftIO $ definitionAt language source uri (positionOf (toJSON params))
        respond $
          Right $
            decodeResult $
              maybe Null (uncurry locationValue) (joinMaybe result)
    , requestHandler SMethod_TextDocumentReferences $ \(TRequestMessage _ _ _ params) respond -> do
        locations <- withDocument (toJSON params) $ \language source uri ->
          pure $ map (locationValue uri) $ case language of
            "core-lambda" -> coreReferencesAt source (positionOf (toJSON params))
            "ski-graph" -> maybe [] symbolOccurrences (skiSymbolAt source (positionOf (toJSON params)))
            _ -> []
        respond $ Right $ decodeResult $ toJSON (fromMaybe [] locations)
    , requestHandler SMethod_TextDocumentDocumentSymbol $ \(TRequestMessage _ _ _ params) respond -> do
        symbols <- withDocument (toJSON params) $ \language source _ ->
          pure $ case language of
            "core-lambda" -> coreDocumentSymbols source
            "ski-graph" -> skiDocumentSymbols source
            _ -> []
        respond $
          Right $
            decodeResult $
              toJSON (maybe [] (map (uncurry documentSymbolValue)) symbols)
    , requestHandler SMethod_TextDocumentSignatureHelp $ \(TRequestMessage _ _ _ params) respond -> do
        result <- withDocument (toJSON params) $ \language source _ ->
          pure $
            if language == "core-lambda"
              then coreSignatureHelp source (positionOf (toJSON params))
              else Nothing
        respond $ Right $ decodeResult $ maybe Null signatureValue (joinMaybe result)
    , requestHandler SMethod_TextDocumentRename $ \(TRequestMessage _ _ _ params) respond -> do
        result <- withDocument (toJSON params) $ \language source uri ->
          pure $ do
            name <- normalizeRename language <$> newNameOf (toJSON params)
            guard
              ( validRename language name
                  && canRename language source (positionOf (toJSON params)) name
              )
            symbol <- symbolAt language source (positionOf (toJSON params))
            guard (not (symbolImported symbol))
            pure (workspaceEditValue uri name (symbolOccurrences symbol))
        respond $ Right $ decodeResult $ fromMaybe Null (joinMaybe result)
    , requestHandler SMethod_TextDocumentPrepareRename $ \(TRequestMessage _ _ _ params) respond -> do
        result <- withDocument (toJSON params) $ \language source _ ->
          pure (prepareRenameAt language source (positionOf (toJSON params)))
        respond $ Right $ decodeResult $ maybe Null rangeValue (joinMaybe result)
    ]

joinMaybe :: Maybe (Maybe a) -> Maybe a
joinMaybe = (>>= id)

symbolAt :: String -> String -> Position -> Maybe Symbol
symbolAt "core-lambda" = coreSymbolAt
symbolAt "ski-graph" = skiSymbolAt
symbolAt _ = \_ _ -> Nothing

definitionAt ::
  String -> String -> LSP.Uri -> Position -> IO (Maybe (LSP.Uri, Range))
definitionAt language source uri position = case symbolAt language source position of
  Nothing -> pure Nothing
  Just symbol -> case (language, coreImportAt source position, LSP.uriToFilePath uri) of
    ("core-lambda", Just (relative, name, _), Just path) -> do
      let target = normalise (takeDirectory path </> relative)
      outcome <- readSource target
      pure $ case outcome >>= (`exportedDefinitionRange` name) of
        Just range -> Just (LSP.filePathToUri target, range)
        Nothing -> Just (uri, symbolDefinition symbol)
    _ -> pure (Just (uri, symbolDefinition symbol))

readSource :: FilePath -> IO (Maybe String)
readSource path = do
  outcome <-
    try (readFile path >>= \content -> evaluate (length content) >> pure content) ::
      IO (Either IOException String)
  pure (either (const Nothing) Just outcome)

publishOpened :: Value -> LspM () ()
publishOpened params = case (uriOf params, documentField "languageId" params, documentField "text" params) of
  (Just uri, Just language, Just source) -> publishEditorDiagnostics uri (issuesFor language source)
  _ -> pure ()

documentField :: (FromJSON a) => Key.Key -> Value -> Maybe a
documentField key (Object params) = do
  Object document <- KeyMap.lookup "textDocument" params
  KeyMap.lookup key document >>= decoded
documentField _ _ = Nothing

issuesFor :: String -> String -> [(Range, String)]
issuesFor "core-lambda" = coreDiagnostics
issuesFor "ski-graph" = skiDiagnostics
issuesFor _ = const []

publishFor :: Value -> LspM () ()
publishFor params = case uriOf params of
  Nothing -> pure ()
  Just uri -> do
    issues <- withDocument params $ \language source _ -> pure (issuesFor language source)
    publishEditorDiagnostics uri (fromMaybe [] issues)

publishEditorDiagnostics :: LSP.Uri -> [(Range, String)] -> LspM () ()
publishEditorDiagnostics uri issues =
  sendNotification SMethod_TextDocumentPublishDiagnostics $
    decodeResult $
      object
        [ "uri" .= uri
        , "diagnostics" .= map (uncurry diagnosticValue) issues
        ]

diagnosticValue :: Range -> String -> Value
diagnosticValue range message =
  object
    [ "range" .= rangeValue range
    , "severity" .= (1 :: Int)
    , "source" .= ("graph-reduction-machine" :: String)
    , "message" .= message
    ]

locationValue :: LSP.Uri -> Range -> Value
locationValue uri range = object ["uri" .= uri, "range" .= rangeValue range]

documentSymbolValue :: String -> Range -> Value
documentSymbolValue name range =
  object
    [ "name" .= name
    , "kind" .= (13 :: Int)
    , "range" .= rangeValue range
    , "selectionRange" .= rangeValue range
    ]

signatureValue :: (String, [String], Int) -> Value
signatureValue (name, parameters, active) =
  object
    [ "signatures"
        .= [ object
               [ "label" .= unwords (name : parameters)
               , "parameters" .= map (\parameter -> object ["label" .= parameter]) parameters
               ]
           ]
    , "activeSignature" .= (0 :: Int)
    , "activeParameter" .= active
    ]

newNameOf :: Value -> Maybe String
newNameOf (Object params) = KeyMap.lookup "newName" params >>= decoded
newNameOf _ = Nothing

validRename :: String -> String -> Bool
validRename "core-lambda" (first : rest) =
  (isAsciiLower first || isAsciiUpper first)
    && all (\character -> isAlphaNum character || character == '_') rest
validRename "ski-graph" ('#' : digits) =
  not (null digits) && all isDigit digits
validRename _ _ = False

normalizeRename :: String -> String -> String
normalizeRename "ski-graph" digits@(_ : _)
  | all isDigit digits = '#' : digits
normalizeRename _ name = name

prepareRenameAt :: String -> String -> Position -> Maybe Range
prepareRenameAt language source position = do
  symbol <- symbolAt language source position
  guard (not (symbolImported symbol))
  let selected = symbolSelection symbol
      selectedText = case selected of
        Range start end -> slice (offsetAt source start) (offsetAt source end) source
  guard (language /= "ski-graph" || selectedText /= "#0")
  pure selected

canRename :: String -> String -> Position -> String -> Bool
canRename "core-lambda" = coreCanRename
canRename "ski-graph" = skiCanRename
canRename _ = \_ _ _ -> False

workspaceEditValue :: LSP.Uri -> String -> [Range] -> Value
workspaceEditValue uri name occurrences =
  object
    [ "changes"
        .= object
          [ uriKey uri
              .= map
                (\range -> object ["range" .= rangeValue range, "newText" .= name])
                occurrences
          ]
    ]

uriKey :: LSP.Uri -> Key.Key
uriKey uri = case toJSON uri of
  String value -> Key.fromText value
  _ -> error "invalid URI"

resolvedCompletionValue :: Value -> Value
resolvedCompletionValue value@(Object item) =
  case KeyMap.lookup "data" item of
    Just (String detail) ->
      Object $
        KeyMap.insert
          "documentation"
          (object ["kind" .= ("markdown" :: String), "value" .= detail])
          item
    _ -> value
resolvedCompletionValue value = value

withDocument ::
  Value -> (String -> String -> LSP.Uri -> LspM () a) -> LspM () (Maybe a)
withDocument params action = case uriOf params of
  Nothing -> pure Nothing
  Just uri -> do
    virtual <- getVirtualFile (LSP.toNormalizedUri uri)
    case virtual of
      Nothing -> pure Nothing
      Just file -> do
        let path = LSP.uriToFilePath uri
            language = case virtualFileLanguageKind file of
              Just kind -> case toJSON kind of
                String name -> Text.unpack name
                _ -> languageFromPath path
              Nothing -> languageFromPath path
        Just <$> action language (Text.unpack (virtualFileText file)) uri

languageFromPath :: Maybe FilePath -> String
languageFromPath path = case takeExtension (fromMaybe "" path) of
  ".lambda" -> "core-lambda"
  ".ski" -> "ski-graph"
  _ -> ""

uriOf :: Value -> Maybe LSP.Uri
uriOf (Object params) = do
  Object doc <- KeyMap.lookup "textDocument" params
  value <- KeyMap.lookup "uri" doc
  decoded value
uriOf _ = Nothing

positionOf :: Value -> Position
positionOf (Object params) = case KeyMap.lookup "position" params of
  Just (Object position) -> Position (readField "line" position) (readField "character" position)
  _ -> Position 0 0
positionOf _ = Position 0 0

readField :: (FromJSON a) => Key.Key -> KeyMap.KeyMap Value -> a
readField key fields = case KeyMap.lookup key fields >>= decoded of
  Just value -> value
  Nothing -> error "invalid LSP position"

decoded :: (FromJSON a) => Value -> Maybe a
decoded value = case fromJSON value of
  Success result -> Just result
  Error _ -> Nothing

decodeResult :: (FromJSON a) => Value -> a
decodeResult value = case fromJSON value of
  Success result -> result
  Error message -> error ("invalid LSP response: " ++ message)

positionValue :: Position -> Value
positionValue (Position line character) = object ["line" .= line, "character" .= character]

rangeValue :: Range -> Value
rangeValue (Range start end) = object ["start" .= positionValue start, "end" .= positionValue end]

completionValue :: Completion -> Value
completionValue (Completion name kind detail documentation range) =
  object
    ( [ "label" .= name
      , "kind" .= kind
      , "textEdit" .= object ["range" .= rangeValue range, "newText" .= name]
      ]
        ++ maybe [] (\value -> ["detail" .= value]) detail
        ++ maybe [] (\value -> ["data" .= value]) documentation
    )

hoverValue :: Hover -> Value
hoverValue (Hover description range) =
  object
    [ "contents" .= object ["kind" .= ("markdown" :: String), "value" .= description]
    , "range" .= rangeValue range
    ]

semanticValue :: [(Range, Int)] -> Value
semanticValue tokens = object ["data" .= go 0 0 tokens]
 where
  go _ _ [] = [] :: [Int]
  go previousLine previousColumn ((Range (Position line column) (Position _ end), kind) : rest) =
    let deltaLine = line - previousLine
        deltaColumn = if deltaLine == 0 then column - previousColumn else column
     in [deltaLine, deltaColumn, end - column, kind, 0] ++ go line column rest

resolveCoreHover :: LSP.Uri -> String -> Position -> IO (Maybe Hover)
resolveCoreHover uri source position = case coreImportAt source position of
  Nothing -> pure (coreHover source position)
  Just (relative, name, range) -> case LSP.uriToFilePath uri of
    Nothing -> pure (coreHover source position)
    Just path -> do
      let target = normalise (takeDirectory path </> relative)
      outcome <-
        try (readFile target >>= \content -> evaluate (length content) >> pure content) ::
          IO (Either IOException String)
      pure $ case either (const Nothing) (`exportedDefinition` name) outcome of
        Just (definition, line) ->
          Just
            ( Hover
                ( "~~~core-lambda\n"
                    ++ definition
                    ++ "\n~~~\n\nDefined in "
                    ++ relative
                    ++ " on line "
                    ++ show line
                )
                range
            )
        Nothing -> coreHover source position
