-- | Read imported source modules relative to the importing file.
module Compiler.ModuleLoader (loadModuleSources) where

import Compiler.ModuleSource (Import (..), Module (..), parseModule)
import Control.Exception (IOException, evaluate, try)
import qualified Data.Map.Strict as Map
import System.FilePath (normalise, takeDirectory, (</>))

loadModuleSources ::
  FilePath -> String -> IO (Either String (Map.Map FilePath String))
loadModuleSources path source =
  case parseModule source of
    Left problem -> pure (Left problem)
    Right parsed -> loadMany Map.empty (importsFrom (normalise path) parsed)
 where
  importsFrom file parsed =
    [ normalise (takeDirectory file </> relative)
    | Import relative _ <- moduleImports parsed
    ]

  loadMany loaded [] = pure (Right loaded)
  loadMany loaded (file : rest)
    | Map.member file loaded = loadMany loaded rest
    | otherwise = do
        outcome <-
          try (readFile file >>= \content -> evaluate (length content) >> pure content) ::
            IO (Either IOException String)
        case outcome of
          Left problem -> pure (Left ("cannot read module " ++ file ++ ": " ++ show problem))
          Right content -> case parseModule content of
            Left problem -> pure (Left (file ++ ": " ++ problem))
            Right parsed ->
              loadMany (Map.insert file content loaded) (importsFrom file parsed ++ rest)
