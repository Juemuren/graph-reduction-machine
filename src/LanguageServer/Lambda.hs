-- | Core Lambda editor analysis using the compiler's BNFC lexer and parser.
module LanguageServer.Lambda (
  coreCompletions,
  coreHover,
  coreImportAt,
  coreSemanticTokens,
  exportedDefinition,
) where

import Control.Monad (guard)
import qualified CoreLambda.Lex as CoreLex
import qualified CoreLambda.Par as Core
import Data.Char (isAlphaNum, isAsciiLower, isAsciiUpper)
import Data.List (find, isPrefixOf)
import LanguageServer.Common

data Declaration = Declaration
  { declarationName :: String
  , declarationToken :: Token
  , declarationDescription :: String
  , declarationPath :: Maybe FilePath
  , declarationExported :: Bool
  }
data Parameter = Parameter
  {parameterToken :: Token, parameterBodyStart :: Int, parameterBodyEnd :: Int}
data CoreAnalysis = CoreAnalysis
  { coreTokens :: [Token]
  , coreDeclarations :: [Declaration]
  , coreParameters :: [Parameter]
  , coreExpressions :: [(Int, Int)]
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
validCoreStatement source tokens end terminated =
  terminated
    && case tokens of
      [] -> False
      first : _ -> case Core.pProgram (Core.myLexer (slice (tokenStart first) end source)) of
        Right _ -> True
        Left _ -> False

analyzeCore :: String -> CoreAnalysis
analyzeCore source =
  let tokens = coreTokensOf source
      parts = statements source tokens
      declarations = concatMap declarationIn parts
      expressions = concatMap expressionIn parts
      parameters = concatMap (parametersIn tokens) expressions
   in CoreAnalysis tokens declarations parameters expressions
 where
  declarationIn (tokens, end, terminated)
    | not (validCoreStatement source tokens end terminated) = []
    | otherwise = case tokens of
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
  expressionIn (tokens, end, terminated) = case tokens of
    directive : _name : equals : _ | tokenText directive == "@>" && tokenText equals == "=" -> [spanAfter equals]
    _name : equals : _ | tokenText equals == "=" -> [spanAfter equals]
    directive : _ | tokenText directive == "@!" -> [spanAfter directive]
    _ -> []
   where
    spanAfter token = (tokenEnd token, if terminated then end - 1 else end)

unquote :: String -> String
unquote value = case reads value of
  [(decoded, "")] -> decoded
  _ -> value

isName :: String -> Bool
isName [] = False
isName (first : rest) =
  (isAsciiUpper first || isAsciiLower first)
    && all (\c -> isAlphaNum c || c == '_') rest

parametersIn :: [Token] -> (Int, Int) -> [Parameter]
parametersIn tokens (start, end) =
  go
    (filter (\token -> tokenStart token >= start && tokenStart token < end) tokens)
 where
  go (slash : name : arrow : rest)
    | tokenText slash == "\\" && tokenText arrow == "->" && isName (tokenText name) =
        Parameter name (tokenEnd arrow) (bodyEnd rest 0) : go (name : arrow : rest)
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
        [ (tokenText (parameterToken parameter), "Parameter")
        | parameter <- activeParameters (coreParameters analysis) offset
        ]
          ++ [ (declarationName declaration, declarationDescription declaration)
             | declaration <- coreDeclarations analysis
             ]
      visible =
        any
          (\(begin, end) -> begin <= offset && offset <= end)
          (coreExpressions analysis)
   in if not visible
        || insideCommentOrString source offset
        || (not (null prefix) && not (isName prefix))
        then []
        else
          [ Completion name description range
          | (name, description) <- unique candidates
          , prefix `isPrefixOf` name
          ]
 where
  namePart character = isAlphaNum character || character == '_'
  unique = go []
  go _ [] = []
  go seen ((name, description) : rest)
    | name `elem` seen = go seen rest
    | otherwise = (name, description) : go (name : seen) rest

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
  token <-
    find
      ( \item ->
          isName (tokenText item) && tokenStart item <= offset && offset < tokenEnd item
      )
      (coreTokens analysis)
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
      Nothing -> Hover . declarationHover source <$> declaration <*> pure range

coreImportAt :: String -> Position -> Maybe (FilePath, String, Range)
coreImportAt source position = do
  let analysis = analyzeCore source
      offset = offsetAt source position
  token <-
    find
      ( \item ->
          isName (tokenText item) && tokenStart item <= offset && offset < tokenEnd item
      )
      (coreTokens analysis)
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
