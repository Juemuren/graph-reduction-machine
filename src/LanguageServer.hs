{-# LANGUAGE OverloadedStrings #-}

module LanguageServer (runLanguageServer) where

import Control.Exception (IOException, evaluate, try)
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
 )
import LanguageServer.Lambda (
  coreCompletions,
  coreHover,
  coreImportAt,
  coreSemanticTokens,
  exportedDefinition,
 )
import LanguageServer.Ski (skiCompletions, skiHover)
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
      , options = defaultOptions
      }

handlers :: Handlers (LspM ())
handlers =
  mconcat
    [ notificationHandler SMethod_Initialized $ \_ -> pure ()
    , notificationHandler SMethod_WorkspaceDidChangeConfiguration $ \_ -> pure ()
    , requestHandler SMethod_TextDocumentCompletion $ \(TRequestMessage _ _ _ params) respond -> do
        items <- withDocument (toJSON params) $ \language source _ ->
          pure $ case language of
            "core-lambda" -> coreCompletions source (positionOf (toJSON params))
            "ski-graph" -> skiCompletions source (positionOf (toJSON params))
            _ -> []
        respond $
          Right $
            LSP.InL (maybe [] (map (decodeResult . completionValue)) items)
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
    ]

joinMaybe :: Maybe (Maybe a) -> Maybe a
joinMaybe = (>>= id)

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
completionValue (Completion name detail range) =
  object
    [ "label" .= name
    , "kind" .= (6 :: Int)
    , "detail" .= detail
    , "textEdit" .= object ["range" .= rangeValue range, "newText" .= name]
    ]

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
