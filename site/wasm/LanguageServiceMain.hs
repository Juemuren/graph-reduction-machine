module Main (main) where

import Data.Char (ord)
import Data.List (intercalate)
import GHC.IO.Encoding (setLocaleEncoding)
import LanguageServer.Common
import LanguageServer.Lambda
import LanguageServer.Service
import LanguageServer.Ski
import Numeric (showHex)
import System.Environment (getArgs)
import System.FilePath (takeExtension)
import System.IO (utf8)

-- The WASI toolchain includes base but does not ship with aeson.
array :: [String] -> String
array values = "[" ++ intercalate "," values ++ "]"

string :: String -> String
string value = "\"" ++ concatMap escape value ++ "\""
 where
  escape '"' = "\\\""
  escape '\\' = "\\\\"
  escape c
    | ord c < 32 =
        let hex = showHex (ord c) ""
         in "\\u" ++ replicate (4 - length hex) '0' ++ hex
    | otherwise = [c]

optional :: (a -> String) -> Maybe a -> String
optional = maybe "null"

range :: Range -> String
range (Range (Position line column) (Position endLine endColumn)) =
  array (map show [line, column, endLine, endColumn])

completion :: Completion -> String
completion (Completion name kind detail docs selection) =
  array
    [ string name
    , show kind
    , optional string detail
    , optional string docs
    , range selection
    ]

main :: IO ()
main = do
  setLocaleEncoding utf8
  args <- getArgs
  case args of
    operation : path : rest -> do
      source <- getContents
      let core = takeExtension path == ".lambda"
          language = if core then "core-lambda" else "ski-graph"
          choose lambda ski = if core then lambda else ski
      result <- case (operation, rest) of
        ("diagnostics", []) ->
          pure $
            array
              [array [range r, string message] | (r, message) <- issuesFor language source]
        ("tokens", []) ->
          pure $
            array
              [array [range r, show kind] | core, (r, kind) <- coreSemanticTokens source]
        ("symbols", []) ->
          pure $
            array
              [ array [string name, range r]
              | (name, r) <- choose coreDocumentSymbols skiDocumentSymbols source
              ]
        (_, line : column : extra) -> do
          let position = Position (read line) (read column)
          case operation of
            "completion" ->
              pure $
                array $
                  map completion (choose coreCompletions skiCompletions source position)
            "hover" -> do
              hovered <-
                if core
                  then resolveCoreHover path source position
                  else pure (skiHover source position)
              pure $
                optional (\(Hover description r) -> array [string description, range r]) hovered
            "definition" ->
              optional (\(file, r) -> array [string file, range r])
                <$> definitionAt language source path position
            "references" ->
              pure $
                array $
                  map range $
                    if core
                      then coreReferencesAt source position
                      else maybe [] symbolOccurrences (skiSymbolAt source position)
            "signature" -> do
              let signature = if core then coreSignatureHelp source position else Nothing
              pure $
                optional
                  ( \(name, params, active) -> array [string name, array (map string params), show active]
                  )
                  signature
            "prepareRename" -> pure $ optional range (prepareRenameAt language source position)
            "rename" -> pure $
              optional (\(name, ranges) -> array [string name, array (map range ranges)]) $
                case extra of
                  [name] -> renameAt language source position name
                  _ -> Nothing
            _ -> fail "Unknown language service operation"
        _ -> fail "Missing language service position"
      putStrLn result
    _ -> fail "Missing language service operation or path"
