-- | Validate the module syntax tree produced by the BNFC parser.
module Compiler.ModuleSource (Module (..), Import (..), parseModule) where

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

data ModulePart
  = ImportPart FilePath [Core.NameRef]
  | ExportPart Core.NameRef Core.Exp
  | DefinitionPart Core.NameRef Core.Exp
  | EntryPart Core.Exp

parseModule :: String -> Either String Module
parseModule source = do
  program <- Core.pProgram (Core.myLexer source)
  (imports, exports, definitions, expression) <-
    foldl collect (Right ([], [], [], Nothing)) (programParts program)
  let names = map fst definitions
  checkUnique "export" exports
  checkUnique "definition" names
  pure
    (Module (reverse imports) (reverse exports) (reverse definitions) expression)
 where
  collect result part = do
    (imports, exports, definitions, expression) <- result
    case part of
      ImportPart path expressions -> do
        names <- mapM expressionName expressions
        when (null path) $ Left "import path must not be empty"
        pure (Import path names : imports, exports, definitions, expression)
      ExportPart name body -> do
        text <- expressionName name
        pure (imports, text : exports, (text, body) : definitions, expression)
      DefinitionPart nameRef body -> do
        name <- expressionName nameRef
        pure (imports, exports, (name, body) : definitions, expression)
      EntryPart body -> case expression of
        Just _ -> Left "duplicate program entry"
        Nothing -> pure (imports, exports, definitions, Just body)

programParts :: Core.Program -> [ModulePart]
programParts program = case program of
  Core.PEmpty -> []
  Core.PImport path names rest -> ImportPart path names : programParts rest
  Core.PExport name body rest -> ExportPart name body : programParts rest
  Core.PDefinition name body rest -> DefinitionPart name body : programParts rest
  Core.PEntry body tail ->
    EntryPart body : case tail of
      Core.EEnd -> []
      Core.EContinue rest -> programParts rest
  Core.PImplicit body _ -> [EntryPart body]

expressionName :: Core.NameRef -> Either String String
expressionName expression = case expression of
  Core.NVariable (Core.Name name) -> Right name
  Core.NBuiltin (Core.Builtin name) -> Right name

checkUnique :: String -> [String] -> Either String ()
checkUnique kind names = case [name | (index, name) <- zip [0 :: Int ..] names, name `elem` take index names] of
  [] -> Right ()
  name : _ -> Left ("duplicate " ++ kind ++ ": " ++ name)
