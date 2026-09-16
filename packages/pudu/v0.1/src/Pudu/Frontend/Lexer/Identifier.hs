{-| @Source.Lexer.Identifier.Module — classifies Unicode names and keywords -}
module Pudu.Frontend.Lexer.Identifier (scanIdentifier) where

import Data.Char (GeneralCategory (DecimalNumber), generalCategory, isLetter)
import Data.Text (Text)
import Pudu.Frontend.Lexer.Cursor
  ( LexerCursor, captureSince, consumeWhile, emitToken, markCursor, peekScalar )
import Pudu.Frontend.Token (TokenKind (Identifier, Keyword), keywordFromText)

scanIdentifier :: LexerCursor -> Maybe LexerCursor
scanIdentifier cursor =
  case peekScalar cursor of
    Just scalar
      | isIdentifierStart scalar ->
          let mark = markCursor cursor
              advanced = consumeWhile isIdentifierContinue cursor
           in do
                (lexeme, _) <- captureSince mark advanced
                emitToken mark (classifyIdentifier lexeme) advanced
    _ -> Nothing

isIdentifierStart :: Char -> Bool
isIdentifierStart scalar = scalar == '_' || isLetter scalar

isIdentifierContinue :: Char -> Bool
isIdentifierContinue scalar =
  isIdentifierStart scalar || generalCategory scalar == DecimalNumber

classifyIdentifier :: Text -> TokenKind
classifyIdentifier lexeme =
  case keywordFromText lexeme of
    Just keyword -> Keyword keyword
    Nothing -> Identifier lexeme
