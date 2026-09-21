{-| @Source.Lexer.Symbol.Module — matches closed punctuation deterministically -}
module Pudu.Frontend.Lexer.Symbol (scanSymbol) where

import Data.List (find, sortOn)
import Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map
import Data.Ord (Down (Down))
import Data.Text (Text)
import qualified Data.Text as Text
import Pudu.Frontend.Lexer.Cursor
  ( LexerCursor, consumeScalars, cursorStartsWith, emitToken, markCursor, peekScalar )
import Pudu.Frontend.Token
  ( SymbolKind, TokenKind (Symbol), symbolText )

scanSymbol :: LexerCursor -> Maybe LexerCursor
scanSymbol cursor = do
  first <- peekScalar cursor
  candidates <- Map.lookup first symbolCandidates
  (spelling, kind) <- find (\(candidate, _) -> cursorStartsWith candidate cursor) candidates
  let mark = markCursor cursor
  emitToken mark (Symbol kind) (consumeScalars (Text.length spelling) cursor)

{-| The symbols that begin with each character, longest first.

    Only the spellings sharing the next character can match, so a symbol is
    decided against the two or three that do rather than against all of them;
    longest first keeps `..=` from being read as `..` followed by `=`. -}
symbolCandidates :: Map Char [(Text, SymbolKind)]
symbolCandidates =
  Map.map (sortOn (Down . Text.length . fst)) $
    Map.fromListWith (<>)
      [ (first, [(spelling, kind)])
      | kind <- [minBound .. maxBound]
      , let spelling = symbolText kind
      , Just (first, _) <- [Text.uncons spelling]
      ]
