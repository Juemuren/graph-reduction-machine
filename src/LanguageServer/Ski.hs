-- | SKI graph editor analysis using the interpreter's BNFC lexer and parser.
module LanguageServer.Ski (
  skiCompletions,
  skiHover,
  skiSymbolAt,
  skiDocumentSymbols,
  skiDiagnostics,
  skiCanRename,
) where

import Data.Char (isDigit)
import Data.List (find, isPrefixOf)
import LanguageServer.Common
import qualified Ski.Lex as SkiLex
import qualified Ski.Par as Ski

skiTokensOf :: String -> [Token]
skiTokensOf source =
  [ Token (SkiLex.tokenText token) start (start + length (SkiLex.tokenText token))
  | token@(SkiLex.PT (SkiLex.Pn start _ _) _) <- SkiLex.tokens source
  ]

skiDefinitions :: String -> [(Token, String)]
skiDefinitions source =
  [ (name, trim (slice (tokenStart name) end source))
  | (tokens, end, _) <- statements source (skiTokensOf source)
  , name : equals : _ <- [tokens]
  , isNodeId (tokenText name)
  , tokenText equals == "="
  ]

isNodeId :: String -> Bool
isNodeId ('#' : digits) = not (null digits) && all isDigit digits
isNodeId _ = False

skiCompletions :: String -> Position -> [Completion]
skiCompletions source position =
  let offset = offsetAt source position
      before = take offset source
      line = reverse (takeWhile (/= '\n') (reverse before))
      prefix = reverse (takeWhile isDigit (reverse line))
      headOffset = offset - length prefix - 1
      beforeReference = take (length line - length prefix - 1) line
      after = takeWhile isDigit (drop offset source)
      range =
        Range (positionAt source headOffset) (positionAt source (offset + length after))
      definitions = skiDefinitions source
   in if headOffset < 0
        || source !! headOffset /= '#'
        || notElem '=' beforeReference
        || "--" `isPrefixOf` dropWhile (/= '-') line
        then []
        else
          [ Completion
              (tokenText token)
              6
              Nothing
              (Just ("```ski-graph\n" ++ description ++ "\n```"))
              range
          | (token, description) <- unique definitions
          ]
 where
  unique = go []
  go _ [] = []
  go seen (item@(token, _) : rest)
    | tokenText token `elem` seen = go seen rest
    | otherwise = item : go (tokenText token : seen) rest

skiHover :: String -> Position -> Maybe Hover
skiHover source position = do
  let offset = offsetAt source position
  token <- tokenAt (isNodeId . tokenText) (skiTokensOf source) offset
  (definition, description) <-
    find ((== tokenText token) . tokenText . fst) (skiDefinitions source)
  let line = positionLine (positionAt source (tokenStart definition)) + 1
  pure
    ( Hover
        ("~~~ski-graph\n" ++ description ++ "\n~~~\n\nDefined on line " ++ show line)
        (tokenRange source token)
    )

skiSymbolAt :: String -> Position -> Maybe Symbol
skiSymbolAt source position = do
  let offset = offsetAt source position
      tokens = skiTokensOf source
  token <- tokenAt (isNodeId . tokenText) tokens offset
  (definition, _) <-
    find ((== tokenText token) . tokenText . fst) (skiDefinitions source)
  pure $
    Symbol
      (tokenRange source token)
      (tokenRange source definition)
      [tokenRange source item | item <- tokens, tokenText item == tokenText token]
      False

skiCanRename :: String -> Position -> String -> Bool
skiCanRename source position newName = case skiSymbolAt source position of
  Nothing -> False
  Just symbol ->
    let current =
          [ tokenText token
          | (token, _) <- skiDefinitions source
          , tokenRange source token == symbolDefinition symbol
          ]
     in (current /= ["#0"] || newName == "#0")
          && all
            ( \(token, _) ->
                tokenText token /= newName || tokenRange source token == symbolDefinition symbol
            )
            (skiDefinitions source)

skiDocumentSymbols :: String -> [(String, Range)]
skiDocumentSymbols source =
  [ (tokenText token, tokenRange source token)
  | (token, _) <- skiDefinitions source
  ]

skiDiagnostics :: String -> [(Range, String)]
skiDiagnostics source = syntaxProblems ++ duplicateProblems ++ missingProblems ++ rootProblem
 where
  tokens = skiTokensOf source
  definitions = skiDefinitions source
  names = map (tokenText . fst) definitions
  syntaxProblems =
    [ (tokenRange source first, "Invalid SKI node definition")
    | (part, end, terminated) <- statements source tokens
    , terminated
    , first : _ <- [part]
    , Left _ <- [Ski.pGraph (Ski.myLexer (slice (tokenStart first) end source))]
    ]
  duplicateProblems =
    [ (tokenRange source token, "Duplicate node: " ++ tokenText token)
    | (index, (token, _)) <- zip [0 :: Int ..] definitions
    , tokenText token `elem` take index names
    ]
  missingProblems =
    [ (tokenRange source token, "Undefined node: " ++ tokenText token)
    | token <- tokens
    , isNodeId (tokenText token)
    , tokenText token `notElem` names
    ]
  rootProblem =
    [ (tokenRange source token, "Missing root node #0")
    | not (null definitions)
    , "#0" `notElem` names
    , (token, _) <- take 1 definitions
    ]
