-- | SKI graph editor analysis using the interpreter's BNFC lexer and parser.
module LanguageServer.Ski (skiCompletions, skiHover) where

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
  | (tokens, end, terminated) <- statements source (skiTokensOf source)
  , terminated
  , name : _ <- [tokens]
  , isNodeId (tokenText name)
  , Right _ <- [Ski.pGraph (Ski.myLexer (slice (tokenStart name) end source))]
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
          [ Completion (tokenText token) description range
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
  token <-
    find
      ( \item ->
          isNodeId (tokenText item) && tokenStart item <= offset && offset < tokenEnd item
      )
      (skiTokensOf source)
  (definition, description) <-
    find ((== tokenText token) . tokenText . fst) (skiDefinitions source)
  let line = positionLine (positionAt source (tokenStart definition)) + 1
  pure
    ( Hover
        ("~~~ski-graph\n" ++ description ++ "\n~~~\n\nDefined on line " ++ show line)
        (tokenRange source token)
    )
