import Distribution.Simple (defaultMainWithHooks, simpleUserHooks)
import Distribution.Simple.UserHooks (UserHooks (preBuild))
import System.Directory (createDirectoryIfMissing, withCurrentDirectory)
import System.Process (callProcess)

main :: IO ()
main = defaultMainWithHooks simpleUserHooks
  { preBuild = \args flags -> do
      createDirectoryIfMissing True "src"
      withCurrentDirectory "src" $ do
        callProcess "bnfc" ["--haskell", "-d", "../grammar/Lambda.cf"]
        callProcess "bnfc" ["--haskell", "-d", "../grammar/Graph.cf"]
      preBuild simpleUserHooks args flags
  }
