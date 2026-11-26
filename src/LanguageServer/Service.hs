-- | Language service operations shared by the native and browser frontends.
module LanguageServer.Service (
  symbolAt,
  definitionAt,
  resolveCoreHover,
  issuesFor,
  prepareRenameAt,
  renameAt,
) where

import Control.Exception (IOException, evaluate, try)
import Control.Monad (guard)
import Data.Char (isAlphaNum, isAsciiLower, isAsciiUpper, isDigit)
import LanguageServer.Common
import LanguageServer.Lambda
import LanguageServer.Ski
import System.FilePath (normalise, takeDirectory, (</>))

symbolAt :: String -> String -> Position -> Maybe Symbol
symbolAt "core-lambda" = coreSymbolAt
symbolAt "ski-graph" = skiSymbolAt
symbolAt _ = \_ _ -> Nothing

definitionAt ::
  String -> String -> FilePath -> Position -> IO (Maybe (FilePath, Range))
definitionAt language source path position = case symbolAt language source position of
  Nothing -> pure Nothing
  Just symbol -> case (language, coreImportAt source position) of
    ("core-lambda", Just (relative, name, _)) -> do
      let target = normalise (takeDirectory path </> relative)
      outcome <- readSource target
      pure $ case outcome >>= (`exportedDefinitionRange` name) of
        Just range -> Just (target, range)
        Nothing -> Just (path, symbolDefinition symbol)
    _ -> pure (Just (path, symbolDefinition symbol))

readSource :: FilePath -> IO (Maybe String)
readSource path = do
  outcome <-
    try (readFile path >>= \content -> evaluate (length content) >> pure content) ::
      IO (Either IOException String)
  pure (either (const Nothing) Just outcome)

issuesFor :: String -> String -> [(Range, String)]
issuesFor "core-lambda" = coreDiagnostics
issuesFor "ski-graph" = skiDiagnostics
issuesFor _ = const []

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

resolveCoreHover :: FilePath -> String -> Position -> IO (Maybe Hover)
resolveCoreHover path source position = case coreImportAt source position of
  Nothing -> pure fallback
  Just (relative, name, range) -> do
    outcome <- readSource (normalise (takeDirectory path </> relative))
    pure $ case outcome >>= (`exportedDefinition` name) of
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
      Nothing -> fallback
 where
  fallback = coreHover source position

renameAt :: String -> String -> Position -> String -> Maybe (String, [Range])
renameAt language source position input = do
  let name = normalizeRename language input
  guard (validRename language name && canRename language source position name)
  symbol <- symbolAt language source position
  guard (not (symbolImported symbol))
  pure (name, symbolOccurrences symbol)
