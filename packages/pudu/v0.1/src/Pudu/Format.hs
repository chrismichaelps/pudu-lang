{-| @Program.Format.Module — renders source in the one committed style -}
module Pudu.Format
  ( FormatResult (..)
  , formatSource
  , formatText
  ) where

import Data.List (sortOn)
import Data.Maybe (mapMaybe)
import Data.Text (Text)
import qualified Data.Text as Text
import Pudu.Diagnostic (Diagnostic, hasErrors)
import Pudu.Frontend.Lexer (LexResult (..), lexSource)
import Pudu.Frontend.Token
  ( Keyword (..)
  , SymbolKind (..)
  , Token (..)
  , TokenKind (..)
  , Trivia (..)
  , TriviaKind (..)
  )
import Pudu.Format.Spacing
  ( Piece (..)
  , closers
  , openers
  , spaced
  )
import Pudu.Source (Position (..), Source, offsetPosition, sourceText, spanStart)

{-| @Format.Result — the formatted text, and what stopped it being formatted.

    Text is returned even when the input does not lex cleanly, because the
    unformattable part is usually one line and a reader still wants the rest.
    `formatChanged` is what a `--check` mode reports on. -}
data FormatResult = FormatResult
  { formatText' :: !Text
  , formatDiagnostics :: ![Diagnostic]
  , formatChanged :: !Bool
  }
  deriving stock (Eq, Show)

{-| Format one source.

    **Lines are never joined or split.** In this language a newline delimits a
    statement, so moving one moves a statement boundary: `a\nb` is two
    statements and `a b` is a syntax error, and a formatter that reflowed would
    be rewriting programs rather than laying them out. Every other formatter
    decision — indentation, spacing inside a line, blank-line runs, the trailing
    newline — is free precisely because none of it can change what the program
    means.

    That constraint is what makes this formatter safe to run on anything: the
    token sequence it emits is the token sequence it read, in the same order,
    on the same lines. -}
formatSource :: Source -> FormatResult
formatSource source =
  FormatResult
    { formatText' = if broken then original else formatted
    , formatDiagnostics = lexDiagnostics result
    , formatChanged = not broken && formatted /= original
    }
 where
  result = lexSource source
  original = renderOriginal source
  broken = hasErrors (lexDiagnostics result) || any isInvalid (lexTokens result)
  formatted = renderTokens source (lexTokens result)
  isInvalid token = case tokenKind token of
    Invalid _ -> True
    _ -> False

{-| Format text that has already been read, for a caller holding no `Source`. -}
formatText :: Source -> Text
formatText = formatText' . formatSource

renderOriginal :: Source -> Text
renderOriginal = sourceText

{-| @Format.Line — one output line: its brace-relative indent and its pieces. -}
data Line = Line !Int ![Piece]

linePieces :: Line -> [Piece]
linePieces (Line _ pieces) = pieces

renderTokens :: Source -> [Token] -> Text
renderTokens source tokens =
  Text.unlines
    ( concatMap
        emitLine
        ( sortImportRuns (layout source tokens)
        )
    )

{-| Lay tokens out on the lines they were written on, with comments taking the
    line they were written on too. -}
layout :: Source -> [Token] -> [Line]
layout source tokens =
  assign (concatMap entries tokens)
 where
  entries token =
    [ (lineOf (triviaSpan trivia), CommentPiece (Text.strip (triviaText trivia)))
    | trivia <- tokenLeadingTrivia token
    , triviaKind trivia /= Whitespace
    ]
      <> [(lineOf (tokenSpan token), TokenPiece token) | tokenKind token /= EndOfFile]
  lineOf spanValue = maybe 0 positionLine (offsetPosition source (spanStart spanValue))
  assign = indentLines . group

{-| Group pieces by the line they were written on, keeping blank-line runs down
    to one. A run of blank lines is the writer separating two things, and one
    line says that as clearly as four. -}
group :: [(Int, Piece)] -> [(Bool, [Piece])]
group [] = []
group ((firstLine, firstPiece) : rest) = go firstLine [firstPiece] rest
 where
  go _ current [] = [(False, reverse current)]
  go previous current ((line, piece) : remaining)
    | line == previous = go previous (piece : current) remaining
    | otherwise =
        (False, reverse current)
          : [(True, []) | line > previous + 1]
            <> go line [piece] remaining

{-| Give every line the indentation its brace depth implies.

    A line that opens with a closing brace or bracket belongs to the level it is
    closing, not the level inside it, so the closer lines up with the line that
    opened it. -}
indentLines :: [(Bool, [Piece])] -> [Line]
indentLines = go [] []
 where
  go _ _ [] = []
  go open above ((blank, pieces) : rest)
    | blank = Line 0 [] : go open above rest
    | otherwise =
        let leading = if startsClosed pieces then 1 else 0
            carried = if continues (inBlock open) pieces || resumes above pieces then 1 else 0
            indent = max 0 (length open - leading + carried)
         in Line indent pieces : go (foldl track open pieces) pieces rest
  {-| The delimiters still open, innermost first. -}
  track open piece = case piece of
    CommentPiece _ -> open
    TokenPiece token -> case tokenKind token of
      Symbol symbol
        | symbol `elem` openers -> symbol : open
        | symbol `elem` closers -> drop 1 open
      _ -> open
  {-| Whether a line starts where statements are written: at the top of a file
      or directly inside a block, rather than inside parentheses or brackets. -}
  inBlock open = case open of
    [] -> True
    innermost : _ -> innermost == SymLeftBrace
  startsClosed pieces = case dropWhile isComment pieces of
    TokenPiece token : _ -> case tokenKind token of
      Symbol symbol -> symbol `elem` closers
      _ -> False
    _ -> False
  isComment piece = case piece of
    CommentPiece _ -> True
    _ -> False

  {-| Whether a line continues the statement above it rather than starting one.

      A line opening with something that cannot begin a statement — `=`, `|`,
      `else`, a binary operator, `.` — is the previous line carried on, and it
      is indented one level past what it continues. Brace depth alone would put
      a sum type's variants hard against the margin, which says the opposite of
      what they are. -}
  continues statementLevel pieces = case dropWhile isComment pieces of
    TokenPiece token : _ -> case tokenKind token of
      {-| A label opens a loop; it never continues the line above. -}
      Symbol SymAt -> False
      Symbol SymHash -> False
      {-| A record written as a change to another opens with `..`, and that is
          the first of its fields rather than the line above carried on. Read as
          a continuation it sat one level deeper than the fields beside it,
          which says the two are not siblings when they are. -}
      Symbol SymRangeExclusive -> False
      {-| A list written one item to a line puts the comma in front of every
          item after the first. Those items are siblings of the first, and the
          bracket they are inside has already been counted, so reading the
          comma as a continuation indented each of them one level past the item
          they line up with. -}
      Symbol SymComma -> False
      {-| Where statements are written, a symbol that can open a prefix
          expression opens a statement when it starts a line: the parser reads
          `*count = 0` on its own line as an assignment through a reference, never
          as the line above multiplied. Inside parentheses or brackets the same
          line is an argument or an item, and keeps the indentation a
          continuation gives it. -}
      Symbol symbol
        | statementLevel && symbol `elem` [SymMinus, SymAmpersand, SymStar] -> False
        | otherwise -> symbol `notElem` (openers <> closers <> [SymBang, SymTilde])
      Keyword KwElse -> True
      _ -> False
    _ -> False

  {-| Whether this line finishes a declaration the line above began.

      A parameter list wrapped onto its own line opens with `(`, which can also
      begin a statement, so the first token cannot decide it alone. What decides
      it is the line above: a declaration that named a function and never opened
      its parameters is not a statement, and what follows belongs to it. Read as
      a statement it sat at the margin, where a reader looking for the next
      declaration finds it instead. -}
  resumes above pieces = startsOpen pieces && awaitingParameters above
  startsOpen ps = case dropWhile isComment ps of
    TokenPiece token : _ -> case tokenKind token of
      Symbol symbol -> symbol == SymLeftParen
      _ -> False
    _ -> False
  awaitingParameters ps =
    declares (dropWhile isComment ps) && not (any isLeftParen ps)
   where
    declares tokens = case tokens of
      TokenPiece token : more -> case tokenKind token of
        Keyword KwFn -> True
        Keyword KwExport -> declares more
        _ -> False
      _ -> False
    isLeftParen piece = case piece of
      TokenPiece token -> tokenKind token == Symbol SymLeftParen
      _ -> False

emitLine :: Line -> [Text]
emitLine (Line indent pieces)
  | null pieces = [Text.empty]
  | otherwise = [Text.replicate indent "  " <> Text.stripEnd (spaced pieces)]

{-| Sort each contiguous run of imports lexically, standard-library first.

    An import's own leading comments travel with it: they describe that import,
    and leaving them behind would attach them to whichever import happened to
    sort into the slot. A run stops at the first line that is not an import, so
    a comment separating two groups keeps its place. -}
sortImportRuns :: [Line] -> [Line]
sortImportRuns lines' = case break isImportLine lines' of
  (before, []) -> before
  (before, rest) ->
    let (run, after) = span isImportLine rest
     in before <> sortOn importKey run <> sortImportRuns after

isImportLine :: Line -> Bool
isImportLine line = case dropWhile isCommentPiece (linePieces line) of
  TokenPiece token : _ -> tokenKind token == Keyword KwImport
  _ -> False
 where
  isCommentPiece piece = case piece of
    CommentPiece _ -> True
    _ -> False

{-| Standard-library imports sort before a program's own, and each group sorts
    lexically by the module it names. -}
importKey :: Line -> (Int, Text)
importKey line = (if Text.isPrefixOf "Std." name then 0 else 1, name)
 where
  name = Text.intercalate "." (mapMaybe segment (drop 1 (tokenPieces line)))
  segment token = case tokenKind token of
    Identifier value -> Just value
    _ -> Nothing

tokenPieces :: Line -> [Token]
tokenPieces line = mapMaybe pick (linePieces line)
 where
  pick piece = case piece of
    TokenPiece token -> Just token
    CommentPiece _ -> Nothing
