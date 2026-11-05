-- | Source positions and result types shared by language analyses.
module LanguageServer.Common (
  Position (..),
  Range (..),
  Completion (..),
  Hover (..),
  Token (..),
  slice,
  positionAt,
  offsetAt,
  tokenRange,
  statements,
  trim,
) where

data Position = Position {positionLine :: Int, positionCharacter :: Int}
  deriving (Eq, Show)
data Range = Range {rangeStart :: Position, rangeEnd :: Position}
  deriving (Eq, Show)
data Completion = Completion
  { completionLabel :: String
  , completionDetail :: String
  , completionRange :: Range
  }
  deriving (Eq, Show)
data Hover = Hover {hoverText :: String, hoverRange :: Range}
  deriving (Eq, Show)

data Token = Token {tokenText :: String, tokenStart :: Int, tokenEnd :: Int}
  deriving (Eq, Show)
slice :: Int -> Int -> String -> String
slice start end = take (end - start) . drop start

-- LSP positions use UTF-16 code units; Alex positions count Haskell characters.
utf16Length :: String -> Int
utf16Length = sum . map (\c -> if fromEnum c > 0xffff then 2 else 1)

positionAt :: String -> Int -> Position
positionAt source offset =
  let before = take offset source
      line = length (filter (== '\n') before)
      column = utf16Length (reverse (takeWhile (/= '\n') (reverse before)))
   in Position line column

offsetAt :: String -> Position -> Int
offsetAt source (Position targetLine targetColumn) = go 0 0 0 source
 where
  go offset line column _ | line == targetLine && column >= targetColumn = offset
  go offset _ _ [] = offset
  go offset line _ ('\n' : rest) = go (offset + 1) (line + 1) 0 rest
  go offset line column (character : rest) =
    go
      (offset + 1)
      line
      (column + if fromEnum character > 0xffff then 2 else 1)
      rest

tokenRange :: String -> Token -> Range
tokenRange source token =
  Range
    (positionAt source (tokenStart token))
    (positionAt source (tokenEnd token))

statements :: String -> [Token] -> [([Token], Int, Bool)]
statements source = go []
 where
  go [] [] = []
  go pending [] = [(reverse pending, length source, False)]
  go pending (token : rest)
    | tokenText token == ";" = (reverse pending, tokenEnd token, True) : go [] rest
    | otherwise = go (token : pending) rest

trim :: String -> String
trim =
  reverse . dropWhile (`elem` " \t\r\n") . reverse . dropWhile (`elem` " \t\r\n")
