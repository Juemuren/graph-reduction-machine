-- | Validate the module syntax tree produced by the BNFC parser.
module ModuleSource (Module (..), Import (..), parseModule) where

import Control.Monad (when)
import qualified CoreLambda.Abs as Core
import qualified CoreLambda.Par as Core

data Import = Import FilePath [String] deriving (Eq, Show)

data Module = Module
  { moduleImports :: [Import]
  , moduleExports :: [String]
  , moduleDefinitions :: [(String, Core.Exp)]
  , moduleExpression :: Maybe Core.Exp
  }

parseModule :: String -> Either String Module
parseModule source = do
  Core.PModule statements <- Core.pProgram (Core.myLexer source)
  (imports, exports, definitions, expression) <-
    foldl collect (Right ([], [], [], Nothing)) statements
  let names = map fst definitions
  checkUnique "definition" names
  checkUnique "export" exports
  pure
    (Module (reverse imports) (reverse exports) (reverse definitions) expression)
 where
  collect result statement = do
    (imports, exports, definitions, expression) <- result
    case expression of
      Just _ -> case statement of
        Core.SEntry _ -> Left "duplicate program entry"
        _ -> Left "program entry must be last"
      Nothing -> pure ()
    case statement of
      Core.SImport path expressions -> do
        names <- mapM expressionName expressions
        when (null path) $ Left "import path must not be empty"
        pure (Import path names : imports, exports, definitions, expression)
      Core.SExport name body -> do
        text <- expressionName name
        pure (imports, text : exports, (text, body) : definitions, expression)
      Core.SDefinition nameRef body -> do
        name <- expressionName nameRef
        pure (imports, exports, (name, body) : definitions, expression)
      Core.SEntry body -> case expression of
        Just _ -> Left "duplicate program entry"
        Nothing -> pure (imports, exports, definitions, Just body)

expressionName :: Core.NameRef -> Either String String
expressionName expression = case expression of
  Core.NVariable (Core.Name name) -> Right name
  Core.NBuiltin (Core.Builtin name) -> Right name

checkUnique :: String -> [String] -> Either String ()
checkUnique kind names = case [name | (index, name) <- zip [0 :: Int ..] names, name `elem` take index names] of
  [] -> Right ()
  name : _ -> Left ("duplicate " ++ kind ++ ": " ++ name)
