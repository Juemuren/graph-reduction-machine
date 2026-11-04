-- | Embed the lambda library when the compiler is built.
module LibrarySource (embeddedSources) where

import Control.Monad (forM)
import Data.List (sort)
import Language.Haskell.TH (Exp, Q)
import Language.Haskell.TH.Syntax (addDependentFile, lift, runIO)
import System.Directory (listDirectory)
import System.FilePath (takeExtension, takeFileName, (</>))

embeddedSources :: Q Exp
embeddedSources = do
  let directory = "lib"
  names <- runIO (listDirectory directory)
  entries <- forM (sort (filter ((== ".lambda") . takeExtension) names)) $ \name -> do
    let path = directory </> name
    addDependentFile path
    source <- runIO (readFile path)
    pure (takeFileName name, source)
  lift entries
