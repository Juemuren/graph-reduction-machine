{-# LANGUAGE OverloadedStrings #-}

module LanguageServer (runLanguageServer) where

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
 )
import LanguageServer.Lambda (
  coreCompletions,
  coreDocumentSymbols,
  coreHover,
  coreReferencesAt,
  coreSemanticTokens,
  coreSignatureHelp,
 )
import qualified LanguageServer.Service as Service
import LanguageServer.Ski (
  skiCompletions,
  skiDocumentSymbols,
  skiHover,
  skiSymbolAt,
 )
import System.FilePath (takeExtension)

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
          "core-lambda" -> liftIO $ case LSP.uriToFilePath uri of
            Just path -> Service.resolveCoreHover path source (positionOf (toJSON params))
            Nothing -> pure (coreHover source (positionOf (toJSON params)))
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
          liftIO $ case LSP.uriToFilePath uri of
            Just path -> do
              target <- Service.definitionAt language source path (positionOf (toJSON params))
              pure $
                fmap
                  (\(file, range) -> (if file == path then uri else LSP.filePathToUri file, range))
                  target
            Nothing ->
              pure $
                (\symbol -> (uri, symbolDefinition symbol))
                  <$> Service.symbolAt language source (positionOf (toJSON params))
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
            input <- newNameOf (toJSON params)
            (name, ranges) <-
              Service.renameAt language source (positionOf (toJSON params)) input
            pure (workspaceEditValue uri name ranges)
        respond $ Right $ decodeResult $ fromMaybe Null (joinMaybe result)
    , requestHandler SMethod_TextDocumentPrepareRename $ \(TRequestMessage _ _ _ params) respond -> do
        result <- withDocument (toJSON params) $ \language source _ ->
          pure (Service.prepareRenameAt language source (positionOf (toJSON params)))
        respond $ Right $ decodeResult $ maybe Null rangeValue (joinMaybe result)
    ]

joinMaybe :: Maybe (Maybe a) -> Maybe a
joinMaybe = (>>= id)

publishOpened :: Value -> LspM () ()
publishOpened params = case (uriOf params, documentField "languageId" params, documentField "text" params) of
  (Just uri, Just language, Just source) -> publishEditorDiagnostics uri (Service.issuesFor language source)
  _ -> pure ()

documentField :: (FromJSON a) => Key.Key -> Value -> Maybe a
documentField key (Object params) = do
  Object document <- KeyMap.lookup "textDocument" params
  KeyMap.lookup key document >>= decoded
documentField _ _ = Nothing

publishFor :: Value -> LspM () ()
publishFor params = case uriOf params of
  Nothing -> pure ()
  Just uri -> do
    issues <- withDocument params $ \language source _ -> pure (Service.issuesFor language source)
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
