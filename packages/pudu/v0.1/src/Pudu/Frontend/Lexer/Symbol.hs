{-| @Source.Lexer.Symbol.Module — matches closed punctuation deterministically -}
module Pudu.Frontend.Lexer.Symbol (scanSymbol) where

import Data.List (find, sortOn)
import Data.Ord (Down (Down))
import Data.Text (Text)
import qualified Data.Text as Text
import Pudu.Frontend.Lexer.Cursor
  ( LexerCursor, consumeScalars, cursorStartsWith, emitToken, markCursor )
import Pudu.Frontend.Token
  ( SymbolKind, TokenKind (Symbol), symbolText )

scanSymbol :: LexerCursor -> Maybe LexerCursor
scanSymbol cursor = do
  (spelling, kind) <- find (\(candidate, _) -> cursorStartsWith candidate cursor) symbolCandidates
  let mark = markCursor cursor
  emitToken mark (Symbol kind) (consumeScalars (Text.length spelling) cursor)

symbolCandidates :: [(Text, SymbolKind)]
symbolCandidates =
  sortOn (Down . Text.length . fst)
    [(symbolText kind, kind) | kind <- [minBound .. maxBound]]
