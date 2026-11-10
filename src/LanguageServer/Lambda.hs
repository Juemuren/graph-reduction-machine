-- | Core Lambda editor analysis using the compiler's BNFC lexer and parser.
module LanguageServer.Lambda (
  coreCompletions,
  coreHover,
  coreImportAt,
  coreSemanticTokens,
  exportedDefinition,
  exportedDefinitionRange,
  coreSymbolAt,
  coreReferencesAt,
  coreDocumentSymbols,
  coreDiagnostics,
  coreSignatureHelp,
  coreCanRename,
) where

import Compiler.Expand (standardLibrarySources)
import Control.Monad (guard)
import qualified CoreLambda.Abs as CoreAbs
import qualified CoreLambda.Lex as CoreLex
import qualified CoreLambda.Par as Core
import Data.Char (isAlphaNum, isAsciiLower, isAsciiUpper, isSpace)
import Data.List (find, isPrefixOf)
import Data.Maybe (isJust, isNothing)
import LanguageServer.Common

data Declaration = Declaration
  { declarationName :: String
  , declarationToken :: Token
  , declarationDescription :: String
  , declarationPath :: Maybe FilePath
  , declarationExported :: Bool
  }
data Parameter = Parameter
  { parameterToken :: Token
  , parameterBodyStart :: Int
  , parameterBodyEnd :: Int
  , parameterOwner :: Maybe String
  }
data Expression = Expression
  { expressionStart :: Int
  , expressionEnd :: Int
  , expressionOwner :: Maybe String
  }
data CoreAnalysis = CoreAnalysis
  { coreTokens :: [Token]
  , coreDeclarations :: [Declaration]
  , coreParameters :: [Parameter]
  , coreExpressions :: [Expression]
  }
coreTokensOf :: String -> [Token]
coreTokensOf source =
  [ Token text start (start + length text)
  | CoreLex.PT (CoreLex.Pn start _ _) value <- CoreLex.tokens source
  , let text = case value of
          CoreLex.T_Name name -> name
          CoreLex.T_Builtin name -> name
          CoreLex.TL value' -> show value'
          CoreLex.TK symbol -> CoreLex.tsText symbol
          _ -> CoreLex.tokenText (CoreLex.PT (CoreLex.Pn start 0 0) value)
  ]

validCoreStatement :: String -> [Token] -> Int -> Bool -> Bool
validCoreStatement source tokens end isFinal = case tokens of
  [] -> False
  first : _ ->
    let input = slice (tokenStart first) end source
     in case Core.pProgram (Core.myLexer input) of
          Right program -> isFinal || isComplete program
          Left _ -> False
 where
  isComplete program = case program of
    CoreAbs.PImport _ _ CoreAbs.PEmpty -> True
    CoreAbs.PExport _ _ CoreAbs.PEmpty -> True
    CoreAbs.PDefinition _ _ CoreAbs.PEmpty -> True
    CoreAbs.PEntry _ (CoreAbs.EContinue CoreAbs.PEmpty) -> True
    _ -> False

analyzeCore :: String -> CoreAnalysis
analyzeCore source =
  let tokens = coreTokensOf source
      parts = statements source tokens
      declarations = concatMap declarationIn parts
      expressions = concatMap (uncurry expressionIn) (zip (finalFlags parts) parts)
      parameters = concatMap (parametersIn tokens) expressions
   in CoreAnalysis tokens declarations parameters expressions
 where
  declarationIn (tokens, end, _terminated) = case tokens of
    directive : path : open : names
      | tokenText directive == "@<" && tokenText open == "(" ->
          [ Declaration
              (tokenText name)
              name
              ("Imported " ++ tokenText name ++ " from " ++ tokenText path)
              (Just (unquote (tokenText path)))
              False
          | name <- takeWhile ((/= ")") . tokenText) names
          , isName (tokenText name)
          ]
    directive : name : equals : _
      | tokenText directive == "@>" && tokenText equals == "=" ->
          [definition name (tokenStart directive) end True]
    name : equals : _ | tokenText equals == "=" -> [definition name (tokenStart name) end False]
    _ -> []
  definition name start end =
    Declaration
      (tokenText name)
      name
      (trim (slice start end source))
      Nothing
  expressionIn isFinal (tokens, end, terminated) = case tokens of
    directive : name : equals : _
      | tokenText directive == "@>" && tokenText equals == "=" ->
          [spanAfter equals (Just (tokenText name))]
    name : equals : _ | tokenText equals == "=" -> [spanAfter equals (Just (tokenText name))]
    directive : _ | tokenText directive == "@!" -> [spanAfter directive Nothing]
    first : _
      | isFinal && isBareExpression tokens ->
          [Expression (tokenStart first) (if terminated then end - 1 else end) Nothing]
    _ -> []
   where
    spanAfter token = Expression (tokenEnd token) (if terminated then end - 1 else end)
    isBareExpression =
      all
        (\token -> tokenText token /= "=" && tokenText token `notElem` ["@<", "@>", "@!"])

finalFlags :: [a] -> [Bool]
finalFlags items = replicate (length items - 1) False ++ [True | not (null items)]

unquote :: String -> String
unquote value = case reads value of
  [(decoded, "")] -> decoded
  _ -> value

isName :: String -> Bool
isName [] = False
isName (first : rest) =
  (isAsciiUpper first || isAsciiLower first)
    && all (\c -> isAlphaNum c || c == '_') rest

parametersIn :: [Token] -> Expression -> [Parameter]
parametersIn tokens expression =
  go
    (filter (\token -> tokenStart token >= start && tokenStart token < end) tokens)
 where
  start = expressionStart expression
  end = expressionEnd expression
  directParameters =
    leadingParameters
      (filter (\token -> tokenStart token >= start && tokenStart token < end) tokens)
  leadingParameters (slash : name : arrow : rest)
    | tokenText slash == "\\" && tokenText arrow == "->" && isName (tokenText name) =
        tokenStart name : leadingParameters rest
  leadingParameters _ = []
  go (slash : name : arrow : rest)
    | tokenText slash == "\\" && tokenText arrow == "->" && isName (tokenText name) =
        Parameter
          name
          (tokenEnd arrow)
          (bodyEnd rest 0)
          ( if tokenStart name `elem` directParameters
              then expressionOwner expression
              else Nothing
          )
          : go (name : arrow : rest)
  go (_ : rest) = go rest
  go [] = []
  bodyEnd [] _ = end
  bodyEnd (token : rest) depth = case tokenText token of
    "(" -> bodyEnd rest (depth + 1)
    ")" | depth == 0 -> tokenStart token
    ")" -> bodyEnd rest (depth - 1)
    _ -> bodyEnd rest depth

activeParameters :: [Parameter] -> Int -> [Parameter]
activeParameters parameters offset =
  reverse
    [ parameter
    | parameter <- parameters
    , parameterBodyStart parameter <= offset
    , offset <= parameterBodyEnd parameter
    ]

coreCompletions :: String -> Position -> [Completion]
coreCompletions source position =
  let analysis = analyzeCore source
      offset = offsetAt source position
      before = take offset source
      after = drop offset source
      prefix = reverse (takeWhile namePart (reverse before))
      suffix = takeWhile namePart after
      start = offset - length prefix
      range = Range (positionAt source start) (positionAt source (offset + length suffix))
      candidates =
        [ ( tokenText (parameterToken parameter)
          , 6
          , Just (maybe "Parameter" ("Parameter of " ++) (parameterOwner parameter))
          , Nothing
          )
        | parameter <- activeParameters (coreParameters analysis) offset
        ]
          ++ [completionFor declaration | declaration <- coreDeclarations analysis]
          ++ [completionFor declaration | declaration <- standardLibraryDeclarations]
      visible =
        any
          ( \expression -> expressionStart expression <= offset && offset <= expressionEnd expression
          )
          (coreExpressions analysis)
   in if not visible
        || insideCommentOrString source offset
        || (not (null prefix) && not (isName prefix))
        then []
        else
          [ Completion name kind detail documentation range
          | (name, kind, detail, documentation) <- unique candidates
          , prefix `isPrefixOf` name
          ]
 where
  completionFor declaration = case declarationPath declaration of
    Just path
      | not (declarationExported declaration) ->
          (declarationName declaration, 6, Just ("from " ++ path), Nothing)
    Nothing ->
      let parameters = functionParameters (declarationDescription declaration)
       in ( declarationName declaration
          , if null parameters then 6 else 3
          , if null parameters then Nothing else Just (unwords parameters)
          , Just ("```core-lambda\n" ++ declarationDescription declaration ++ "\n```")
          )
    Just path ->
      let parameters = functionParameters (declarationDescription declaration)
       in ( declarationName declaration
          , if null parameters then 6 else 3
          , if null parameters then Nothing else Just (unwords parameters)
          , Just
              ("```core-lambda\n" ++ declarationDescription declaration ++ "\n```\n\n" ++ path)
          )
  namePart character = isAlphaNum character || character == '_'
  unique = go []
  go _ [] = []
  go seen (item@(name, _, _, _) : rest)
    | name `elem` seen = go seen rest
    | otherwise = item : go (name : seen) rest

insideCommentOrString :: String -> Int -> Bool
insideCommentOrString source offset =
  let line = reverse (takeWhile (/= '\n') (reverse (take offset source)))
   in case break (== '#') line of
        (_, []) -> odd (length (filter (== '"') line))
        (code, _) -> odd (length (filter (== '"') code)) || length code < length line

coreHover :: String -> Position -> Maybe Hover
coreHover source position = do
  let analysis = analyzeCore source
      offset = offsetAt source position
  token <- tokenAt (isName . tokenText) (coreTokens analysis) offset
  let ownDeclaration =
        find
          ((== tokenStart token) . tokenStart . declarationToken)
          (coreDeclarations analysis)
      ownParameter =
        find
          ((== tokenStart token) . tokenStart . parameterToken)
          (coreParameters analysis)
      parameter = case ownParameter of
        Just value -> Just value
        Nothing ->
          find
            ((== tokenText token) . tokenText . parameterToken)
            (activeParameters (coreParameters analysis) (tokenStart token))
      declaration = case ownDeclaration of
        Just value -> Just value
        Nothing -> find ((== tokenText token) . declarationName) (coreDeclarations analysis)
      range = tokenRange source token
  case ownDeclaration of
    Just value -> Just (Hover (declarationHover source value) range)
    Nothing -> case parameter of
      Just value ->
        Just
          ( Hover
              ( "Parameter "
                  ++ tokenText token
                  ++ "\n\nDefined on line "
                  ++ show (positionLine (positionAt source (tokenStart (parameterToken value))) + 1)
              )
              range
          )
      Nothing ->
        case declaration of
          Just value -> Just (Hover (declarationHover source value) range)
          Nothing -> Hover <$> standardLibraryHover (tokenText token) <*> pure range

coreImportAt :: String -> Position -> Maybe (FilePath, String, Range)
coreImportAt source position = do
  let analysis = analyzeCore source
      offset = offsetAt source position
  token <- tokenAt (isName . tokenText) (coreTokens analysis) offset
  let shadowed =
        any
          (\item -> tokenText (parameterToken item) == tokenText token)
          (activeParameters (coreParameters analysis) (tokenStart token))
  guard (not shadowed)
  declaration <-
    find ((== tokenText token) . declarationName) (coreDeclarations analysis)
  relative <- declarationPath declaration
  pure (relative, tokenText token, tokenRange source token)

-- | Token kinds use the standard semantic token legend: parameter (7), variable (8).
coreSemanticTokens :: String -> [(Range, Int)]
coreSemanticTokens source =
  [ (tokenRange source token, kind)
  | token <- coreTokens analysis
  , isName (tokenText token)
  , let ownParameter =
          any
            ((== tokenStart token) . tokenStart . parameterToken)
            (coreParameters analysis)
        parameter =
          any
            (\item -> tokenText (parameterToken item) == tokenText token)
            (activeParameters (coreParameters analysis) (tokenStart token))
        declaration = any ((== tokenText token) . declarationName) (coreDeclarations analysis)
  , kind <- if ownParameter || parameter then [7] else [8 | declaration]
  ]
 where
  analysis = analyzeCore source

declarationHover :: String -> Declaration -> String
declarationHover source declaration =
  let line =
        show
          (positionLine (positionAt source (tokenStart (declarationToken declaration))) + 1)
   in case declarationPath declaration of
        Just _ -> declarationDescription declaration ++ "\n\nImported on line " ++ line
        Nothing ->
          "~~~core-lambda\n"
            ++ declarationDescription declaration
            ++ "\n~~~\n\nDefined on line "
            ++ line

-- | Find only a public definition in an imported module.
exportedDefinition :: String -> String -> Maybe (String, Int)
exportedDefinition source name = do
  declaration <-
    find
      (\item -> declarationName item == name && declarationExported item)
      (coreDeclarations (analyzeCore source))
  let line =
        positionLine (positionAt source (tokenStart (declarationToken declaration))) + 1
  pure (declarationDescription declaration, line)

{- | The declaration and all references which resolve to it in this document.
Imported names are local bindings, but cannot be renamed without editing the
exporting module too.
-}
coreSymbolAt :: String -> Position -> Maybe Symbol
coreSymbolAt source position = do
  let analysis = analyzeCore source
      offset = offsetAt source position
  token <- tokenAt (isName . tokenText) (coreTokens analysis) offset
  origin <- resolveToken analysis token
  definition <- find ((== origin) . tokenStart) (coreTokens analysis)
  let occurrences =
        [ tokenRange source item
        | item <- coreTokens analysis
        , resolveToken analysis item == Just origin
        ]
      imported =
        any
          ( \item ->
              tokenStart (declarationToken item) == origin && isJust (declarationPath item)
          )
          (coreDeclarations analysis)
  pure $
    Symbol
      (tokenRange source token)
      (tokenRange source definition)
      occurrences
      imported

coreReferencesAt :: String -> Position -> [Range]
coreReferencesAt source position = case coreSymbolAt source position of
  Just symbol -> symbolOccurrences symbol
  Nothing -> case tokenAt (isName . tokenText) (coreTokens analysis) offset of
    Nothing -> []
    Just selected ->
      [ tokenRange source token
      | token <- coreTokens analysis
      , tokenText token == tokenText selected
      , isNothing (resolveToken analysis token)
      ]
 where
  analysis = analyzeCore source
  offset = offsetAt source position

coreCanRename :: String -> Position -> String -> Bool
coreCanRename source position newName = case coreSymbolAt source position of
  Nothing -> False
  Just symbol ->
    not (symbolImported symbol)
      && all
        ( \token ->
            tokenText token /= newName || tokenRange source token == symbolDefinition symbol
        )
        ( map declarationToken (coreDeclarations analysis)
            ++ map parameterToken (coreParameters analysis)
        )
 where
  analysis = analyzeCore source

resolveToken :: CoreAnalysis -> Token -> Maybe Int
resolveToken analysis token
  | not (isName (tokenText token)) = Nothing
  | otherwise =
      case find
        ((== tokenStart token) . tokenStart . parameterToken)
        (coreParameters analysis) of
        Just parameter -> Just (tokenStart (parameterToken parameter))
        Nothing -> case find
          ((== tokenStart token) . tokenStart . declarationToken)
          (coreDeclarations analysis) of
          Just declaration -> Just (tokenStart (declarationToken declaration))
          Nothing -> case find
            ((== tokenText token) . tokenText . parameterToken)
            (activeParameters (coreParameters analysis) (tokenStart token)) of
            Just parameter -> Just (tokenStart (parameterToken parameter))
            Nothing ->
              tokenStart . declarationToken
                <$> find ((== tokenText token) . declarationName) (coreDeclarations analysis)

coreDocumentSymbols :: String -> [(String, Range)]
coreDocumentSymbols source =
  [ (declarationName declaration, tokenRange source (declarationToken declaration))
  | declaration <- coreDeclarations (analyzeCore source)
  , isNothing (declarationPath declaration)
  ]

exportedDefinitionRange :: String -> String -> Maybe Range
exportedDefinitionRange source name = do
  declaration <-
    find
      (\item -> declarationName item == name && declarationExported item)
      (coreDeclarations (analyzeCore source))
  pure (tokenRange source (declarationToken declaration))

coreDiagnostics :: String -> [(Range, String)]
coreDiagnostics source = syntaxProblems ++ duplicateProblems ++ unknownProblems
 where
  analysis = analyzeCore source
  parts = statements source (coreTokens analysis)
  declarations = coreDeclarations analysis
  syntaxProblems =
    [ (tokenRange source first, "Invalid Core Lambda statement")
    | (isFinal, (tokens, end, _)) <- zip (finalFlags parts) parts
    , not (validCoreStatement source tokens end isFinal)
    , first : _ <- [tokens]
    ]
  duplicateProblems =
    [ ( tokenRange source (declarationToken declaration)
      , "Duplicate definition: " ++ declarationName declaration
      )
    | (index, declaration) <- zip [0 :: Int ..] declarations
    , any
        ((== declarationName declaration) . declarationName)
        (take index declarations)
    ]
  unknownProblems =
    [ (tokenRange source token, "Undefined name: " ++ tokenText token)
    | token <- coreTokens analysis
    , case tokenText token of
        first : _ -> isAsciiLower first || isAsciiUpper first
        _ -> False
    , any
        ( \expression ->
            expressionStart expression <= tokenStart token
              && tokenStart token < expressionEnd expression
        )
        (coreExpressions analysis)
    , isNothing (resolveToken analysis token)
    , tokenText token `notElem` standardLibraryNames
    ]

standardLibraryDeclarations :: [Declaration]
standardLibraryDeclarations =
  [ declaration{declarationPath = Just path}
  | (path, source) <- standardLibrarySources
  , declaration <- coreDeclarations (analyzeCore source)
  , declarationExported declaration
  , case declarationName declaration of
      first : _ -> isAsciiUpper first
      _ -> False
  ]

standardLibraryNames :: [String]
standardLibraryNames = map declarationName standardLibraryDeclarations

standardLibraryHover :: String -> Maybe String
standardLibraryHover name = do
  declaration <- find ((== name) . declarationName) standardLibraryDeclarations
  path <- declarationPath declaration
  source <- lookup path standardLibrarySources
  let line =
        positionLine (positionAt source (tokenStart (declarationToken declaration))) + 1
  pure $
    "~~~core-lambda\n"
      ++ declarationDescription declaration
      ++ "\n~~~\n\nDefined in "
      ++ path
      ++ " on line "
      ++ show line

coreSignatureHelp :: String -> Position -> Maybe (String, [String], Int)
coreSignatureHelp source position = do
  let analysis = analyzeCore source
      offset = offsetAt source position
  expression <-
    find
      (\item -> expressionStart item <= offset && offset <= expressionEnd item)
      (coreExpressions analysis)
  let before =
        filter
          ( \token -> expressionStart expression <= tokenStart token && tokenEnd token <= offset
          )
          (coreTokens analysis)
      callable token =
        any
          ( \declaration ->
              declarationName declaration == tokenText token
                && isNothing (declarationPath declaration)
          )
          (coreDeclarations analysis)
      candidates = filter callable before
  function <- case reverse candidates of
    item : _ -> Just item
    [] -> Nothing
  declaration <-
    find ((== tokenText function) . declarationName) (coreDeclarations analysis)
  let params = functionParameters (declarationDescription declaration)
      completed =
        length
          [ token
          | token <- before
          , tokenStart token > tokenStart function
          , tokenEnd token < offset
          , isName (tokenText token)
          ]
  guard (not (null params) && completed < length params)
  pure (declarationName declaration, params, completed)

functionParameters :: String -> [String]
functionParameters source = go (drop 1 (dropWhile (/= '=') source))
 where
  go input = case dropWhile isSpace input of
    '\\' : rest ->
      let (name, tailText) = span (\character -> isAlphaNum character || character == '_') rest
       in case dropWhile isSpace tailText of
            '-' : '>' : remaining | not (null name) -> name : go remaining
            _ -> []
    _ -> []
