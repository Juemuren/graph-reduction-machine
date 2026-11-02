import Distribution.Simple (defaultMainWithHooks, simpleUserHooks)
import Distribution.Simple.UserHooks (UserHooks (preBuild))
import System.Directory (createDirectoryIfMissing, withCurrentDirectory)
import System.Process (callProcess)

main :: IO ()
main = defaultMainWithHooks simpleUserHooks
  { preBuild = \args flags -> do
      createDirectoryIfMissing True "src"
      withCurrentDirectory "src" $
        callProcess "bnfc" ["--haskell", "-d", "../grammar/Syntax.cf"]
      preBuild simpleUserHooks args flags
  }
