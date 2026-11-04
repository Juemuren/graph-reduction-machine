-- | Embed standard-library modules when the compiler is built.
module Compiler.LibrarySource (embeddedSources) where

import Control.Monad (forM)
import Data.List (sort)
import Language.Haskell.TH (Exp, Q)
import Language.Haskell.TH.Syntax (addDependentFile, lift, runIO)
import System.Directory (doesDirectoryExist, listDirectory)
import System.FilePath (takeExtension, (</>))

embeddedSources :: Q Exp
embeddedSources = do
  paths <- collect "lib" ""
  entries <- forM paths $ \relative -> do
    let path = "lib" </> relative
    addDependentFile path
    source <- runIO (readFile path)
    pure (relative, source)
  lift entries

collect :: FilePath -> FilePath -> Q [FilePath]
collect root relative = do
  names <- sort <$> runIO (listDirectory (root </> relative))
  concat <$> forM names (visit root relative)
 where
  visit base parent name = do
    let path = parent </> name
    directory <- runIO (doesDirectoryExist (base </> path))
    if directory
      then collect base path
      else pure [path | takeExtension path == ".lambda"]
