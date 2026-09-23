{-| @Program.Format.Spacing — piece classification and spacing rules for formatting -}
module Pudu.Format.Spacing
  ( Piece (..)
  , Shape (..)
  , BraceStyle (..)
  , attachedBrace
  , paddedBrace
  , classify
  , prefixKinds
  , braceKinds
  , lambdaBars
  , unaryOperators
  , openers
  , closers
  , isSymbol
  , render
  , wantsSpace
  , spaced
  ) where

import Data.Char (isUpper)
import Data.Text (Text)
import qualified Data.Text as Text
import Pudu.Frontend.Token
  ( Keyword (..)
  , SymbolKind (..)
  , Token (..)
  , TokenKind (..)
  )

{-| @Format.Piece — a token or a comment. -}
data Piece
  = TokenPiece !Token
  | CommentPiece !Text

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
  {-| Whether this piece is the bar that closes a function literal's parameter
      list, which takes no space before it: `|x| x + 1`. -}
  , shapeClosingBar :: !Bool
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
classify pieces =
  zipWith3 Shape (braceKinds pieces) (prefixKinds pieces bars) (map (== Just False) bars)
 where
  bars = lambdaBars pieces

{-| Whether each piece is a prefix operator rather than a binary one.

    `!`, `-`, `&`, `~`, and `*` are spelled the same either way, and only what
    precedes them tells the two apart: an operator follows an operand, and a
    prefix follows anything else. `a - b` subtracts and `(-b)` negates, `a * b`
    multiplies and `*handle` reads through a borrow. A prefix binds to its
    operand and takes no space after it. -}
prefixKinds :: [Piece] -> [Maybe Bool] -> [Bool]
prefixKinds pieces bars = go Nothing (zip pieces bars)
 where
  go _ [] = []
  go previous ((piece, bar) : rest) = case piece of
    CommentPiece _ -> False : go previous rest
    TokenPiece token ->
      let kind = tokenKind token
          isPrefix = case kind of
            {-| The bar that opens a parameter list attaches to the first
                parameter, exactly as a prefix operator attaches to its
                operand. -}
            Symbol SymPipe -> bar == Just True
            Symbol symbol | symbol `elem` unaryOperators -> not (endsOperand previous)
            _ -> False
       in isPrefix : go (Just kind) rest

{-| Whether what precedes a symbol was a value, which is what separates a binary
    operator from a prefix one and a bar that joins from a bar that opens a
    function literal. -}
endsOperand :: Maybe TokenKind -> Bool
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

{-| The symbols that attach to what follows them when nothing precedes them as
    an operand.

    `..` is here for the record written as a change to another — `Thing{..base}`
    — and for a range with no lower end, `items[..5]`. A range between two
    operands is spelled tight as well, which the range rule in `wantsSpace`
    decides rather than this list.

    A bar is not here. `|` is spelled the same as the operator that joins two
    values and as the separator between a sum's variants, and telling those from
    a function literal's parameter list takes more than what precedes it, which
    is what `lambdaBars` does. -}
unaryOperators :: [SymbolKind]
unaryOperators =
  [SymBang, SymMinus, SymAmpersand, SymTilde, SymStar, SymRangeExclusive]

{-| Which bars belong to a function literal's parameter list, and which end of
    one each is.

    `|` is spelled three ways in this language: the operator that joins two
    values, the separator between a sum's variants and between a pattern's
    alternatives, and the pair that holds a function literal's parameters. The
    first is told apart by what precedes it — an operator follows a value and a
    literal's bar does not.

    The second cannot be, because both are written where no value precedes them:
    `| Stale(V)` on its own line separates variants and `|x| x * 2` opens a
    literal. What follows decides instead. A literal's parameter list holds
    lowercase names and ends with a bar, a comma, or a type annotation; a
    variant or an alternative names a constructor, which is capitalised. So a
    bar is a literal's when the name after it is lowercase and the token after
    that could close or continue a parameter list.

    The closing bar is found as the partner of the opening one, because on its
    own it is spelled exactly like the operator. -}
lambdaBars :: [Piece] -> [Maybe Bool]
lambdaBars pieces = go Nothing False (tails' pieces)
 where
  tails' values = case values of
    [] -> []
    _ : rest -> values : tails' rest

  go _ _ [] = []
  go previous open (current : remaining) = case current of
    [] -> []
    piece : rest -> case piece of
      CommentPiece _ -> Nothing : go previous open remaining
      TokenPiece token ->
        let kind = tokenKind token
         in case kind of
              Symbol SymPipe
                | open -> Just False : go (Just kind) False remaining
                | not (endsOperand previous) && opensParameters rest ->
                    Just True : go (Just kind) True remaining
              _ -> Nothing : go (Just kind) open remaining

  {-| Whether what follows a bar reads as a parameter list. An empty one is
      written `||`, which the lexer gives as one token, so a bar immediately
      followed by another is not this. -}
  opensParameters rest = case [token | TokenPiece token <- rest] of
    first : second : _ -> valueName (tokenKind first) && continues (tokenKind second)
    _ -> False

  valueName kind = case kind of
    Identifier value -> maybe False (\(scalar, _) -> scalar == '_' || not (isUpper scalar)) (Text.uncons value)
    _ -> False

  continues kind = case kind of
    Symbol symbol -> symbol `elem` [SymPipe, SymComma, SymColon]
    _ -> False

openers :: [SymbolKind]
openers = [SymLeftBrace, SymLeftParen, SymLeftBracket]

closers :: [SymbolKind]
closers = [SymRightBrace, SymRightParen, SymRightBracket]

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
              | not inHead && recordAt index =
                  if keywordBefore index then Selection else Record
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

  {-| Whether what precedes a brace admits a record shape rather than a block.

      A name before it is the construction `User{id: 1}`. A binding keyword, a
      `case`, a field's colon, or an opening delimiter is a pattern position,
      where `{x, y}` takes a record apart and no block is admissible — so it
      holds its fields against the braces, like the record it matches. -}
  namedBefore index = case precedingKind index of
    Just (Identifier _) -> True
    Just (Symbol SymRightBracket) -> True
    Just (Keyword keyword) -> keyword `elem` patternKeywords
    Just (Symbol symbol) ->
      symbol `elem` [SymColon, SymComma, SymLeftParen, SymLeftBracket]
    _ -> False

  {-| A record pattern opened by a keyword keeps the space that separates it
      from the keyword — `let {x, y}`, not `let{x, y}` — while still holding
      its fields tight. That is the same pair of answers an import's selection
      list gives, which is why it is written as one. -}
  keywordBefore index = case precedingKind index of
    Just (Keyword keyword) -> keyword `elem` patternKeywords
    _ -> False

  precedingKind index = case [token | (position, token) <- tokens, position < index] of
    [] -> Nothing
    earlier -> Just (tokenKind (last earlier))

  patternKeywords = [KwLet, KwVar, KwConst, KwCase]

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
    {-| A range is written tight, both ends and either end absent: `0..n`,
        `0..=n`, `items[2..]`, `items[..2]`. It reads as one value that way,
        which is what it is. -}
    | isRange left || isRange right = False
    {-| The bar that closes a function literal's parameter list attaches to the
        last parameter, matching the bar that opened the list. -}
    | shapeClosingBar shape = False
    | shapePrefix leftShape = False
    | isSymbol right SymColon = False
    | isSymbol left SymColon = True
    {-| A name followed by `!` is a macro call, `twice!(20)`: `!` is never an
        operator after an operand, so the name and its bang are one thing. -}
    | isIdentifier left && isSymbol right SymBang = False
    | isSymbol left SymBang && closesGroup right = False
    {-| A block handed to a call opens against the parenthesis, as a macro's
        `block` argument is written: `timed!({ work() })`. -}
    | isSymbol left SymLeftParen && isSymbol right SymLeftBrace = False
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

  isIdentifier kind = case kind of
    Identifier _ -> True
    _ -> False

  isRange kind = isSymbol kind SymRangeExclusive || isSymbol kind SymRangeInclusive

  {-| A `(` follows its callee with no space, and follows a keyword with one:
      `run(x)` but `if (a)`. -}
  callableBefore kind = case kind of
    Identifier _ -> True
    {-| `fn(A) -> B` names a function type and `fn(x: Int) => x` writes one, and
        both are spelled tight. -}
    Keyword KwFn -> True
    {-| `unsafe(foreign)` names the abilities a region is granted rather than
        grouping a condition, so it is spelled tight like an argument list —
        which is what every diagnostic that asks a reader to write one shows. -}
    Keyword KwUnsafe -> True
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
