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

{-| @Format.Piece — a token or a comment. -}
data Piece
  = TokenPiece !Token
  | CommentPiece !Text

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
indentLines = go 0
 where
  go _ [] = []
  go depth ((blank, pieces) : rest)
    | blank = Line 0 [] : go depth rest
    | otherwise =
        let opened = sum (map delta pieces)
            leading = if startsClosed pieces then 1 else 0
            carried = if continues pieces then 1 else 0
            indent = max 0 (depth - leading + carried)
         in Line indent pieces : go (max 0 (depth + opened)) rest
  delta piece = case piece of
    CommentPiece _ -> 0
    TokenPiece token -> case tokenKind token of
      Symbol symbol
        | symbol `elem` openers -> 1
        | symbol `elem` closers -> -1
      _ -> 0
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
  continues pieces = case dropWhile isComment pieces of
    TokenPiece token : _ -> case tokenKind token of
      {-| A label opens a loop; it never continues the line above. -}
      Symbol SymAt -> False
      Symbol SymHash -> False
      Symbol symbol -> symbol `notElem` (openers <> closers <> [SymBang, SymTilde])
      Keyword KwElse -> True
      _ -> False
    _ -> False

openers :: [SymbolKind]
openers = [SymLeftBrace, SymLeftParen, SymLeftBracket]

closers :: [SymbolKind]
closers = [SymRightBrace, SymRightParen, SymRightBracket]

emitLine :: Line -> [Text]
emitLine (Line indent pieces)
  | null pieces = [Text.empty]
  | otherwise = [Text.replicate indent "  " <> Text.stripEnd (spaced pieces)]

{-| Join a line's pieces with the spacing the style calls for.

    Each brace is classified once, before any spacing is decided, so a closing
    brace is always spaced like the brace it closes. -}
spaced :: [Piece] -> Text
spaced pieces = case zip pieces (classify pieces) of
  [] -> Text.empty
  first : rest -> go (render (fst first)) first rest
 where
  go accumulated _ [] = accumulated
  go accumulated (previous, leftShape) ((piece, shape) : remaining) =
    let separator =
          if wantsSpace leftShape shape previous piece then " " else Text.empty
     in go (accumulated <> separator <> render piece) (piece, shape) remaining

{-| @Format.Shape — what a piece is, where its own spelling does not say.

    Both facts need a look at the pieces around them, so they are decided once
    for the whole line before any spacing is. -}
data Shape = Shape
  { shapeBrace :: !BraceStyle
  , shapePrefix :: !Bool
  }

{-| @Format.BraceStyle — which of the three things a brace pair is.

    They differ in two independent ways, which is why one flag was not enough:
    whether the brace sits against what precedes it, and whether it holds its
    contents apart.

    * `Record` — `User{id: 1}`: attached, unpadded.
    * `Selection` — `import Std.Num {Add, Mul}`: detached, unpadded.
    * `Block` — `if ready { 1 }`: detached, padded. -}
data BraceStyle = Record | Selection | Block
  deriving stock (Eq)

attachedBrace :: BraceStyle -> Bool
attachedBrace style = style == Record

paddedBrace :: BraceStyle -> Bool
paddedBrace style = style == Block

{-| Classify every piece on a line. -}
classify :: [Piece] -> [Shape]
classify pieces = zipWith Shape (braceKinds pieces) (prefixKinds pieces)

{-| Whether each piece is a prefix operator rather than a binary one.

    `!`, `-`, `&`, `~`, and `*` are spelled the same either way, and only what
    precedes them tells the two apart: an operator follows an operand, and a
    prefix follows anything else. `a - b` subtracts and `(-b)` negates, `a * b`
    multiplies and `*handle` reads through a borrow. A prefix binds to its
    operand and takes no space after it. -}
prefixKinds :: [Piece] -> [Bool]
prefixKinds pieces = go Nothing pieces
 where
  go _ [] = []
  go previous (piece : rest) = case piece of
    CommentPiece _ -> False : go previous rest
    TokenPiece token ->
      let kind = tokenKind token
          isPrefix = case kind of
            Symbol symbol | symbol `elem` unaryOperators -> not (endsOperand previous)
            _ -> False
       in isPrefix : go (Just kind) rest

  endsOperand previous = case previous of
    Nothing -> False
    Just kind -> case kind of
      Identifier _ -> True
      IntegerLiteral _ -> True
      FloatLiteral _ -> True
      DecimalLiteral _ -> True
      StringLiteral _ -> True
      TemplateLiteral _ -> True
      CharLiteral _ -> True
      Keyword keyword -> keyword `elem` [KwTrue, KwFalse, KwNull]
      Symbol symbol -> symbol `elem` [SymRightParen, SymRightBracket, SymRightBrace, SymQuestion]
      _ -> False

{-| The symbols that may begin an operand as well as join two. -}
{-| The symbols that attach to what follows them when nothing precedes them as
    an operand.

    `..` is here for the record written as a change to another: after the brace
    there is no operand, so it attaches — `Thing{..base}`. Between two operands
    it is the range it has always been and is spaced as one, which is why
    membership in this list is not the whole test. -}
unaryOperators :: [SymbolKind]
unaryOperators =
  [SymBang, SymMinus, SymAmpersand, SymTilde, SymStar, SymRangeExclusive]

{-| Whether each piece, if it is a brace, belongs to a tightly written pair.

    A record construction is written tight — `User{id: 1}` — and a block is
    not. From the token stream those two look identical at the opening brace, so
    the decision is made from the shape that follows it: a record's brace is
    followed by a field list, `name:` or `name,` or `name}`. The name before the
    brace must also be one a type could be, and the brace must not be closing a
    control-flow head, which the grammar already forbids a record construction
    from opening. -}
braceKinds :: [Piece] -> [BraceStyle]
braceKinds pieces
  | selectsImports = map (const Selection) pieces
  | otherwise = go [] False [] (zip [0 ..] pieces)
 where
  {-| An import's selection list is neither a record nor a body: it takes a
      space before its brace and none inside. -}
  selectsImports = case [token | TokenPiece token <- pieces] of
    token : _ -> tokenKind token == Keyword KwImport
    [] -> False
  tokens = [(index, token) | (index, TokenPiece token) <- zip [0 :: Int ..] pieces]
  go _ _ _ [] = []
  go stack inHead heads ((index, piece) : rest) = case piece of
    TokenPiece token -> case tokenKind token of
      Symbol SymLeftBrace ->
        let style
              | setAt index = Record
              | not inHead && recordAt index = Record
              | otherwise = Block
         in style : go (style : stack) False heads rest
      Symbol SymRightBrace -> case stack of
        top : below -> top : go below inHead heads rest
        [] -> Block : go [] inHead heads rest
      Keyword keyword | keyword `elem` headKeywords -> Block : go stack True heads rest
      {-| A `{` after a return arrow opens a body, never a record: `-> Int {` is
          a function's result followed by what computes it. -}
      Symbol SymThinArrow -> Block : go stack True heads rest
      {-| A parenthesised expression inside a head is not the head's own brace
          position, so `for x in (Thing{v: 1})` still holds a record. The head
          resumes at the closing parenthesis rather than ending there: a pattern
          carries parentheses of its own, and `if let Some(found) = value { … }`
          opens a body, not a record named `value`. -}
      Symbol SymLeftParen -> Block : go stack False (inHead : heads) rest
      Symbol SymRightParen -> case heads of
        saved : below -> Block : go stack saved below rest
        [] -> Block : go stack inHead [] rest
      _ -> Block : go stack inHead heads rest
    CommentPiece _ -> Block : go stack inHead heads rest

  recordAt index = namedBefore index && fieldsAfter index

  setAt index = case [token | (position, token) <- tokens, position < index] of
    [] -> False
    earlier -> tokenKind (last earlier) == Symbol SymHash

  namedBefore index = case [token | (position, token) <- tokens, position < index] of
    [] -> False
    earlier -> case tokenKind (last earlier) of
      Identifier _ -> True
      Symbol SymRightBracket -> True
      _ -> False

  fieldsAfter index = case [token | (position, token) <- tokens, position > index] of
    {-| An empty pair right after a name is a record construction with no
        fields — `Silent{}` — and stays tight like any other. -}
    first : _ | closesImmediately first -> True
    {-| A leading `..` is a record written as a change to another, which is a
        record construction and is written tight like the rest. No block begins
        with a range. -}
    first : _ | opensUpdate first -> True
    first : second : _ -> named first && follows second
    [first] -> named first
    [] -> False
   where
    {-| A field name is a lowercase identifier. That is what separates a
        shorthand field list from a block whose value happens to be a bare
        name: `Point{x}` constructs and `{ HalfEven }` yields. -}
    named token = case tokenKind token of
      Identifier value -> maybe False (isFieldStart . fst) (Text.uncons value)
      _ -> False
    follows token = case tokenKind token of
      Symbol symbol -> symbol `elem` [SymColon, SymComma, SymRightBrace]
      _ -> False

  isFieldStart scalar = scalar == '_' || (scalar >= 'a' && scalar <= 'z')

  closesImmediately token = case tokenKind token of
    Symbol SymRightBrace -> True
    _ -> False

  opensUpdate token = case tokenKind token of
    Symbol SymRangeExclusive -> True
    _ -> False

{-| The keywords whose head runs up to a block, where the grammar does not admit
    a record construction. -}
headKeywords :: [Keyword]
headKeywords = [KwIf, KwWhile, KwFor, KwMatch, KwElse]

render :: Piece -> Text
render piece = case piece of
  CommentPiece text -> text
  TokenPiece token -> tokenLexeme token

{-| Whether two adjacent pieces are separated by a space.

    Each side's `Shape` says whether it is a brace belonging to a
    tightly written pair — a record construction — which is the only thing that
    separates `User{id: 1}` from `if ready { 1 }`. Both sides are needed
    because a brace's spacing is decided by the pair it belongs to, not by the
    token that happens to sit next to it. -}
wantsSpace :: Shape -> Shape -> Piece -> Piece -> Bool
wantsSpace leftShape shape before after = case (before, after) of
  (CommentPiece _, _) -> True
  (_, CommentPiece _) -> True
  (TokenPiece left, TokenPiece right) -> between (tokenKind left) (tokenKind right)
 where
  between left right
    | isSymbol left SymComma = True
    | isSymbol right SymComma = False
    | isSymbol left SymDot || isSymbol right SymDot = False
    {-| A label is one thing: `@outer`, never `@ outer`. -}
    | isSymbol left SymAt = False
    | shapePrefix leftShape = False
    | isSymbol right SymColon = False
    | isSymbol left SymColon = True
    | isSymbol left SymBang && closesGroup right = False
    | isSymbol right SymRightBrace =
        paddedBrace (shapeBrace shape) && not (isSymbol left SymLeftBrace)
    | isSymbol left SymLeftBrace =
        paddedBrace (shapeBrace leftShape) && not (isSymbol right SymRightBrace)
    | isSymbol right SymLeftBrace = not (attachedBrace (shapeBrace shape))
    | any (isSymbol left) openers = False
    | any (isSymbol right) closers = False
    | isSymbol right SymLeftParen = not (callableBefore left)
    | isSymbol right SymLeftBracket = not (indexableBefore left)
    | otherwise = True

  closesGroup kind = any (isSymbol kind) closers

  {-| A `(` follows its callee with no space, and follows a keyword with one:
      `run(x)` but `if (a)`. -}
  callableBefore kind = case kind of
    Identifier _ -> True
    {-| `fn(A) -> B` names a function type and `fn(x: Int) => x` writes one, and
        both are spelled tight. -}
    Keyword KwFn -> True
    Symbol symbol -> symbol `elem` (closers <> [SymBang, SymQuestion])
    _ -> False

  {-| A `[` indexes what precedes it with no space, but opens an array literal
      with one when nothing indexable precedes. -}
  indexableBefore kind = case kind of
    Identifier _ -> True
    Symbol symbol -> symbol `elem` closers
    _ -> False

isSymbol :: TokenKind -> SymbolKind -> Bool
isSymbol kind expected = case kind of
  Symbol symbol -> symbol == expected
  _ -> False

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
