{-| @Program.Parser.Expression — applies explicit expression precedence -}
module Pudu.Frontend.Parser.Expression
  ( BlockParser
  , parseExpression
  , parseExpressionAt
  , parseScrutinee
  ) where

import Data.List.NonEmpty (NonEmpty (..))
import Data.Text (Text)
import qualified Data.Text as Text
import Pudu.Frontend.Parser.Expression.Aggregate
  ( blockExpression
  , literal
  , parseArrayLiteral
  , parseSetLiteral
  , parseGrouped
  , parseNameOrRecord
  )
import Pudu.Frontend.Parser.Expression.Control
  ( ExpressionParsers (..)
  , parseFor
  , parseIf
  , parseLabelled
  , parseLoop
  , parseMatch
  , parseWhile
  )
import Pudu.Frontend.Parser.Expression.Postfix (parsePostfix)
import Pudu.Frontend.Parser.Expression.Recovery
  ( AmbiguityRecovery (..)
  , beginsExpression
  , continuesAcrossLineBreak
  , invalidAtCurrent
  , invalidPrefix
  , isPrefixCapableBinary
  , mergedOrLeft
  , parseCapabilityAnnotation
  , reservedKeywordGuidance
  , reservedPrefix
  , reportAmbiguousLineBreak
  , unaryOperators
  )
import Pudu.Frontend.Parser.State
  ( BlockParser
  , Parser
  , advanceToken
  , emitParseError
  , expectSymbol
  , isSymbol
  , lookaheadKind
  , matchKeyword
  , matchSymbol
  , expectKeyword
  , peekKind
  , peekStartsLine
  , peekToken
  , withRecords
  , withoutRecords
  , withRecursionBudget
  , withTokens
  )
import Pudu.Frontend.Parser.Name (expectValueIdentifier)
import Pudu.Frontend.Parser.Type (parseTypeSyntax)
import Pudu.Frontend.Syntax.Located (Located (..))
import Pudu.Frontend.Syntax.Tree
  ( Expression (..)
  , Function (..)
  , FunctionBody (..)
  , Literal (..)
  , Parameter (..)
  , TypeSyntax
  , Visibility (Private)
  , lambdaName
  )
import Pudu.Frontend.Token
  ( Keyword (KwAsync, KwFalse, KwFn, KwFor, KwIf, KwIn, KwLoop
    , KwMatch, KwMut, KwNull, KwScope, KwTrue, KwUnsafe, KwWhile, KwWith)
  , TemplatePart (..)
  , SymbolKind (..)
  , Token (..)
  , TokenKind (..)
  , symbolText
  )
import Pudu.Source (Span)


{-| The entry points [[Parser Expression Control]] reads expressions through.

    Control forms contain expressions and expressions contain control forms, so
    one direction has to be a capability rather than an import. This is that
    direction, and it is the same trick the block parser already uses. -}
controlParsers :: ExpressionParsers
controlParsers =
  ExpressionParsers parseDelimitedExpression parseDelimitedScrutinee parseDelimitedExpressionAt

parseExpression :: BlockParser -> Parser (Located Expression)
parseExpression blockParser = parseExpressionAt blockParser 0

parseDelimitedExpression :: BlockParser -> Parser (Located Expression)
parseDelimitedExpression blockParser = parseDelimitedExpressionAt blockParser 0

{-| Parse the expression that precedes a block: an `if` or `while` condition, a
    `match` scrutinee, or a `for` iterable. A record construction is not
    admitted here, because `if READY { ... }` would otherwise be ambiguous with
    the block that follows. Parentheses reinstate it. -}
parseScrutinee :: BlockParser -> Parser (Located Expression)
parseScrutinee = parseDelimitedScrutinee

parseDelimitedScrutinee :: BlockParser -> Parser (Located Expression)
parseDelimitedScrutinee blockParser =
  withoutRecords (parseDelimitedExpressionAt blockParser 0)

{-| Records are admitted again inside any bracketed context, so an argument, an
    index, or a parenthesized expression may construct one. -}
parseExpressionAt :: BlockParser -> Int -> Parser (Located Expression)
parseExpressionAt = parseExpressionAtWith PreserveStatement

parseDelimitedExpressionAt :: BlockParser -> Int -> Parser (Located Expression)
parseDelimitedExpressionAt = parseExpressionAtWith RecoverOwner

parseExpressionAtWith
  :: AmbiguityRecovery
  -> BlockParser
  -> Int
  -> Parser (Located Expression)
parseExpressionAtWith recovery blockParser minimumPrecedence =
  fst <$> parseExpressionTracked recovery blockParser minimumPrecedence True

{-| Parse an expression beside whether its binary chain crossed a line through
    an operator written at the start of that line.

    Only the public entry for one expression may report the mixed-chain
    ambiguity. Recursive right operands return the fact to that owner instead,
    so a precedence descent cannot emit the same diagnostic more than once. -}
parseExpressionTracked
  :: AmbiguityRecovery
  -> BlockParser
  -> Int
  -> Bool
  -> Parser (Located Expression, Bool)
parseExpressionTracked recovery blockParser minimumPrecedence mayReportAmbiguity = do
  bounded <- withRecursionBudget $ do
    prefix <- parsePrefix recovery blockParser
    postfixed <- parsePostfix controlParsers blockParser prefix
    parseBinaryTail recovery blockParser minimumPrecedence mayReportAmbiguity False postfixed
  case bounded of
    Just result -> pure result
    Nothing -> do
      invalid <- invalidAtCurrent
      pure (invalid, False)

parsePrefix :: AmbiguityRecovery -> BlockParser -> Parser (Located Expression)
parsePrefix recovery blockParser = do
  token <- peekToken
  following <- lookaheadKind 1
  let nextIsFunction = following == Keyword KwFn
      nextIsShortLambda = following `elem` [Symbol SymPipe, Symbol SymLogicalOr]
  case tokenKind token of
    IntegerLiteral value -> literal token (IntegerValue value)
    FloatLiteral value -> literal token (FloatValue value)
    DecimalLiteral value -> literal token (DecimalValue value)
    StringLiteral value -> literal token (StringValue value)
    TemplateLiteral parts -> parseTemplate blockParser token parts
    CharLiteral value -> literal token (CharValue value)
    Keyword KwTrue -> literal token (BoolValue True)
    Keyword KwFalse -> literal token (BoolValue False)
    Keyword KwNull -> literal token NullValue
    Keyword KwIf -> parseIf controlParsers blockParser
    Keyword KwMatch -> parseMatch controlParsers blockParser
    Keyword KwWhile -> parseWhile controlParsers blockParser Nothing
    Keyword KwUnsafe -> parseUnsafeBlock blockParser
    Keyword KwFn -> parseLambda recovery blockParser
    Keyword KwAsync
      | nextIsFunction -> parseLambda recovery blockParser
      {-| `async |x| ...` is the short literal of an asynchronous function, the
          way `async fn(x) => ...` is the long one. Without it the short form
          would be the spelling a reader reaches for until the moment the body
          has to await something, and then they would have to rewrite it. -}
      | nextIsShortLambda -> advanceToken >> parseShortLambda True recovery blockParser
      | otherwise -> parseScope blockParser
    Keyword KwLoop -> parseLoop controlParsers blockParser Nothing
    Keyword KwFor -> parseFor controlParsers blockParser Nothing
    Identifier name -> parseNameOrRecord controlParsers blockParser token name
    Symbol SymAt -> parseLabelled controlParsers blockParser
    Symbol SymPipe -> parseShortLambda False recovery blockParser
    {-| `||` is the zero-parameter short literal. The lexer cannot know that —
        it sees the boolean operator's spelling — so the decision is made here,
        where a binary operator could not appear anyway. -}
    Symbol SymLogicalOr -> parseShortLambda False recovery blockParser
    Symbol SymRangeExclusive -> parseOpenLowerRange recovery blockParser False
    Symbol SymRangeInclusive -> parseOpenLowerRange recovery blockParser True
    Symbol symbol
      | symbol == SymLeftParen -> withRecords (parseGrouped controlParsers blockParser)
      | symbol == SymLeftBrace -> blockExpression controlParsers blockParser
      | symbol == SymLeftBracket -> parseArrayLiteral controlParsers blockParser
      | symbol == SymHash -> parseSetLiteral controlParsers blockParser
      | symbol `elem` unaryOperators -> parseUnary recovery blockParser token symbol
    Keyword keyword | Just guidance <- reservedKeywordGuidance keyword ->
      reservedPrefix token guidance
    _ -> invalidPrefix token

{-| Build the expression an interpolated string stands for.

    `"a{x}b"` is `"a" + show(x) + "b"`. It is sugar rather than a node of its
    own because there is nothing a template means that concatenation does not,
    and every later phase — resolution, typing, evaluation — would otherwise
    need a case for a construct with no new meaning.

    Each hole is wrapped in `show`, so a value of any type may be interpolated
    and text keeps its own content rather than gaining the quotes rendering
    would add. -}
parseTemplate :: BlockParser -> Token -> [TemplatePart] -> Parser (Located Expression)
parseTemplate blockParser token parts = do
  _ <- advanceToken
  pieces <- mapM (templatePiece blockParser (tokenSpan token)) parts
  pure (Located (tokenSpan token) (concatenate (tokenSpan token) pieces))

{-| One part as an expression: text as itself, a hole as `show` of what it
    holds. -}
templatePiece :: BlockParser -> Span -> TemplatePart -> Parser (Located Expression)
templatePiece blockParser wholeSpan part = case part of
  TemplateText text -> pure (Located wholeSpan (LiteralExpression (StringValue text)))
  TemplateHole holeSpan source -> do
    inner <- parseHole blockParser holeSpan source
    pure
      ( Located holeSpan
          ( CallExpression
              (Located holeSpan (NameExpression (renderName :| [])))
              [inner]
          )
      )

{-| Read an interpolation's expression from the tokens the lexer made for it.

    An empty interpolation cannot reach here — the lexer refuses one — so the
    only way this produces nothing is a malformed expression, which reports
    itself the way any malformed expression does. -}
parseHole :: BlockParser -> Span -> [Token] -> Parser (Located Expression)
parseHole blockParser holeSpan tokens =
  withTokens tokens (parseDelimitedExpression blockParser)
    >>= \parsed -> pure (Located holeSpan (locatedValue parsed))

{-| The name a hole's value is rendered through.

    `display` rather than `show`: a message being built wants a string's own
    content, not the quotes an inspection would add. -}
renderName :: Text
renderName = "display"

{-| Text pieces joined with `+`, which is what a template means.

    An empty template is empty text rather than nothing, so `""` and a template
    with no parts agree. -}
concatenate :: Span -> [Located Expression] -> Expression
concatenate wholeSpan pieces = case pieces of
  [] -> LiteralExpression (StringValue Text.empty)
  first : rest -> locatedValue (foldl joinWith first rest)
 where
  joinWith left right =
    Located wholeSpan (BinaryExpression left "+" right)

{-| Parse a function literal: `fn(x) => x + 1` or `fn(x: Int) -> Int { ... }`.

    The `fn` keyword is reused rather than a new sigil introduced, because the
    function *type* is already written `fn(A) -> T` and a literal that spells
    itself the same way needs nothing explained. It cannot be ambiguous: `fn`
    could not previously begin an expression at all.

    Both bodies are admitted for the same reason a declaration admits both. `=>`
    reads as "answers with", matching its meaning in a match arm, and the block
    form is there when the answer takes more than one step.

    A literal's parameters take no defaults. A default is part of a named
    function's documented interface, and a literal has no name to document; a
    caller looking at a value of type `fn(Int) -> Int` has nowhere to learn that
    one of its arguments was optional. -}
parseLambda :: AmbiguityRecovery -> BlockParser -> Parser (Located Expression)
parseLambda recovery blockParser = do
  start <- peekToken
  asyncKeyword <- matchKeyword KwAsync
  _ <- expectKeyword KwFn "to start a function literal"
  _ <- expectSymbol "(" "before the parameter list"
  parameters <- parseLambdaParameters ")" []
  _ <- expectSymbol ")" "after the parameter list"
  returnType <- parseLambdaReturn
  body <- parseLambdaBody recovery blockParser
  let endSpan = maybe (tokenSpan start) locatedSpan body
  pure
    ( Located (mergedOrLeft (tokenSpan start) endSpan)
        ( LambdaExpression
            Function
              { functionVisibility = Private
              , functionAsync = maybe False (const True) asyncKeyword
              , functionUnsafe = Nothing
              , functionComptime = False
              , functionName = Located (tokenSpan start) lambdaName
              , functionTypeParams = []
              , functionParameters = parameters
              , functionReturn = returnType
              , functionConstraints = []
              , functionBody = body
              }
        )
    )

{-| A literal's parameters: a name and an optional type, separated by commas.

    The closing delimiter is given rather than assumed, because the two literal
    spellings close their parameter list differently — `fn(x)` with a bracket,
    `|x|` with the bar it opened with — and everything between the delimiters is
    the same in both. -}
parseLambdaParameters :: Text -> [Located Parameter] -> Parser [Located Parameter]
parseLambdaParameters closer reversed = do
  closing <- isSymbol closer <$> peekKind
  if closing
    then pure (reverse reversed)
    else do
      name <- expectValueIdentifier "in the parameter list"
      annotation <- parseLambdaAnnotation
      let parameter =
            Located (locatedSpan name)
              Parameter
                { parameterName = name
                , parameterType = annotation
                , parameterDefault = Nothing
                }
          extended = parameter : reversed
      separator <- matchSymbol ","
      case separator of
        Just _ -> parseLambdaParameters closer extended
        Nothing -> pure (reverse extended)

{-| Parse the short function literal: `|x| x + 1`, `|x: Int| x + 1`, `||42`.

    It is the same value `fn(x) => x + 1` builds, written the way a reader
    writes one when the literal is an argument and the interesting part is the
    body. `fn` says what a function *is*, which a declaration needs; passing one
    to `map` does not, and three tokens of ceremony around a one-token body is
    the difference between a program that reads as what it does and one that
    reads as how it is spelled.

    The bars cannot be mistaken for the operator they share a spelling with. A
    binary `|` never appears where an operand is expected, which is the only
    position this is read in, so a leading bar here is always a literal's.

    The body is one expression, and `{` opens a block expression as it does
    anywhere else, so `|x| { ... }` needs no rule of its own. A result type may
    follow the bars — `|x| -> Int { ... }` — because `->` cannot begin an
    expression and so cannot be mistaken for the body; that keeps the short form
    able to say everything the long one says rather than being the form a reader
    has to abandon the moment they want to write a type down.

    A parameter takes no default, for the reason the long form takes none: a
    caller holding a value of function type has nowhere to learn that an
    argument was optional. -}
parseShortLambda
  :: Bool -> AmbiguityRecovery -> BlockParser -> Parser (Located Expression)
parseShortLambda asynchronous recovery blockParser = do
  start <- peekToken
  parameters <- case tokenKind start of
    Symbol SymLogicalOr -> advanceToken >> pure []
    _ -> do
      _ <- advanceToken
      declared <- parseLambdaParameters "|" []
      _ <- expectSymbol "|" "after the parameter list"
      pure declared
  returnType <- parseLambdaReturn
  body <- parseExpressionAtWith recovery blockParser 0
  pure
    ( Located (mergedOrLeft (tokenSpan start) (locatedSpan body))
        ( LambdaExpression
            Function
              { functionVisibility = Private
              , functionAsync = asynchronous
              , functionUnsafe = Nothing
              , functionComptime = False
              , functionName = Located (tokenSpan start) lambdaName
              , functionTypeParams = []
              , functionParameters = parameters
              , functionReturn = returnType
              , functionConstraints = []
              , functionBody = Just (Located (locatedSpan body) (ExpressionBody body))
              }
        )
    )

{-| Parse a range written with no lower end: `..upper`, `..=upper`, or `..`.

    It means "from the beginning", which only an indexable value can answer, so
    the absent end is carried to the index rather than resolved here. A bare
    `..` is admitted because `items[..]` is the whole of something whose length
    the writer does not have to ask for; `..=` with no upper end is not, because
    an inclusive end that is not written includes nothing in particular. -}
parseOpenLowerRange
  :: AmbiguityRecovery -> BlockParser -> Bool -> Parser (Located Expression)
parseOpenLowerRange recovery blockParser inclusive = do
  operator <- advanceToken
  upper <- parseRangeUpper recovery blockParser inclusive (tokenSpan operator)
  let ending = maybe (tokenSpan operator) locatedSpan upper
  pure (Located (mergedOrLeft (tokenSpan operator) ending) (RangeExpression Nothing inclusive upper))

{-| The end of a range, where one is written.

    Whether one is written is decided by the token that follows rather than by
    trying and recovering: a range's end is genuinely optional, so a `]` after
    `..` is the range ending rather than a mistake, and only a token that could
    begin an expression is read as one. A line break ends it too, because a
    statement ends at a line break here. -}
parseRangeUpper
  :: AmbiguityRecovery -> BlockParser -> Bool -> Span -> Parser (Maybe (Located Expression))
parseRangeUpper recovery blockParser inclusive operatorSpan = do
  kind <- peekKind
  newLine <- peekStartsLine
  if beginsExpression kind && not newLine
    then Just <$> parseExpressionAtWith recovery blockParser (rangePrecedence + 1)
    else
      if inclusive
        then do
          emitParseError "E1063" operatorSpan "an inclusive range needs an end"
            (Just "write the last value after ..=, or use .. for a range with no end")
          pure Nothing
        else pure Nothing

parseLambdaAnnotation :: Parser (Maybe (Located TypeSyntax))
parseLambdaAnnotation = do
  colon <- matchSymbol ":"
  case colon of
    Nothing -> pure Nothing
    Just _ -> Just <$> parseTypeSyntax

parseLambdaReturn :: Parser (Maybe (Located TypeSyntax))
parseLambdaReturn = do
  arrow <- matchSymbol "->"
  case arrow of
    Nothing -> pure Nothing
    Just _ -> Just <$> parseTypeSyntax

{-| `=>` answers with one expression; `{` opens a block. Anything else is an
    incomplete literal, and saying which two forms exist is more useful than
    naming the token that was found. -}
parseLambdaBody
  :: AmbiguityRecovery
  -> BlockParser
  -> Parser (Maybe (Located FunctionBody))
parseLambdaBody recovery blockParser = do
  arrow <- matchSymbol "=>"
  case arrow of
    Just _ -> do
      value <- parseExpressionAtWith recovery blockParser 0
      pure (Just (Located (locatedSpan value) (ExpressionBody value)))
    Nothing -> do
      opening <- isSymbol "{" <$> peekKind
      if opening
        then do
          block <- blockParser
          pure (Just (Located (locatedSpan block) (BlockBody block)))
        else do
          token <- peekToken
          emitParseError "E1032" (tokenSpan token)
            "expected a function literal's body"
            (Just "follow the parameter list with => and one expression, or a block")
          pure Nothing

{-| Parse `async with scope { ... }`, the structured task scope.

    Every child a scope starts is joined before the scope's value is produced,
    so no task outlives the region that started it. The keywords are spelled out
    because the construct is a promise about lifetime, not a modifier. -}
parseScope :: BlockParser -> Parser (Located Expression)
parseScope blockParser = do
  keyword <- advanceToken
  _ <- expectKeyword KwWith "after async to open a structured scope"
  _ <- expectKeyword KwScope "after with to open a structured scope"
  body <- blockParser
  pure
    ( Located (mergedOrLeft (tokenSpan keyword) (locatedSpan body))
        (ScopeExpression body)
    )

{-| Parse `unsafe { ... }` or `unsafe(raw, null) { ... }`.

    A capability list names exactly which unchecked abilities the block grants;
    an empty list grants all of them. Naming them is what makes an unsafe region
    auditable: the reader sees which invariant is in play without reading the
    body. -}
parseUnsafeBlock :: BlockParser -> Parser (Located Expression)
parseUnsafeBlock blockParser = do
  keyword <- advanceToken
  capabilities <- parseCapabilityAnnotation
  body <- blockParser
  pure
    ( Located (mergedOrLeft (tokenSpan keyword) (locatedSpan body))
        (UnsafeExpression capabilities body)
    )

parseUnary
  :: AmbiguityRecovery
  -> BlockParser
  -> Token
  -> SymbolKind
  -> Parser (Located Expression)
parseUnary recovery blockParser operatorToken operator = do
  _ <- advanceToken
  rendered <- if operator == SymAmpersand
    then maybe "&" (const "&mut") <$> matchKeyword KwMut
    else pure (symbolText operator)
  {-| A prefix operator binds tighter than every binary one, so its operand is
      parsed above the highest binary precedence. At the multiplying level it
      was inside it, and `*a * *b` parsed as `*(a * (*b))` — a dereference of a
      product rather than a product of two dereferences. -}
  operand <- parseExpressionAtWith recovery blockParser (highestBinaryPrecedence + 1)
  pure (Located (mergedOrLeft (tokenSpan operatorToken) (locatedSpan operand))
    (UnaryExpression rendered operand))

{-| The precedence of the tightest-binding binary operator.

    Named rather than written as a number where it is used, so a new operator
    added to the table below cannot leave the prefix rule behind. -}
highestBinaryPrecedence :: Int
highestBinaryPrecedence = 8


parseBinaryTail
  :: AmbiguityRecovery
  -> BlockParser
  -> Int
  -> Bool
  -> Bool
  -> Located Expression
  -> Parser (Located Expression, Bool)
parseBinaryTail recovery blockParser minimumPrecedence mayReportAmbiguity crossedLeading left = do
  kind <- peekKind
  newLine <- peekStartsLine
  {-| A line beginning with a function literal's bar starts a statement rather
      than joining the line above. `|` is spelled the same as the operator that
      joins two values, so without this a literal written as a block's result —
      which is where a literal most often goes in a language whose blocks are
      expressions — was read as a bitwise or of the statement before it, and
      reported as an unresolved parameter name somewhere else entirely. -}
  lambdaAhead <- opensShortLambda
  if newLine && lambdaAhead
    then pure (left, crossedLeading)
    else case rangeInfo kind of
      Just inclusive
        | rangePrecedence >= minimumPrecedence
        , not newLine -> do
        operator <- advanceToken
        upper <- parseRangeUpper recovery blockParser inclusive (tokenSpan operator)
        let ending = maybe (tokenSpan operator) locatedSpan upper
            combined = Located (mergedOrLeft (locatedSpan left) ending)
              (RangeExpression (Just left) inclusive upper)
        {-| A range is not chainable: `1..2..3` names no value, and reading it as
            one range inside another would report a type error about a shape the
            writer never meant to build. -}
        following <- peekKind
        case rangeInfo following of
          Just _ -> do
            token <- peekToken
            emitParseError "E1062" (tokenSpan token) "a range cannot be chained"
              (Just "a range has two ends; parenthesize if an end is itself a range")
          Nothing -> pure ()
        parseBinaryTail recovery blockParser minimumPrecedence mayReportAmbiguity
          (crossedLeading || newLine) combined
      _ -> parseOperatorTail recovery blockParser minimumPrecedence mayReportAmbiguity
        crossedLeading left kind newLine

{-| Whether the parser is looking at the bar that opens a function literal's
    parameter list, rather than at the operator or the alternation that share
    its spelling.

    What follows decides it, because what precedes it cannot: both appear where
    no value does. A parameter list holds lowercase names and continues with a
    bar, a comma, or a type annotation; an alternative or a variant names a
    constructor, which is capitalised. The same three tokens decide it in
    [[Format Spacing]], and for the same reason. -}
opensShortLambda :: Parser Bool
opensShortLambda = do
  kind <- peekKind
  following <- lookaheadKind 1
  after <- lookaheadKind 2
  pure (kind == Symbol SymPipe && parameterName following && continuesParameters after)
 where
  parameterName kind = case kind of
    Identifier value ->
      maybe False (\(scalar, _) -> scalar == '_' || (scalar >= 'a' && scalar <= 'z'))
        (Text.uncons value)
    _ -> False
  continuesParameters kind = case kind of
    Symbol symbol -> symbol `elem` [SymPipe, SymComma, SymColon]
    _ -> False

{-| The two range spellings, and whether the end they name is included. -}
rangeInfo :: TokenKind -> Maybe Bool
rangeInfo kind = case kind of
  Symbol SymRangeExclusive -> Just False
  Symbol SymRangeInclusive -> Just True
  _ -> Nothing

{-| Where a range binds. Between the bitwise operators and comparison, so
    `0..n + 1` runs to `n + 1` and `x in 0..n` compares the range rather than
    ranging over the comparison. -}
rangePrecedence :: Int
rangePrecedence = 5

parseOperatorTail
  :: AmbiguityRecovery
  -> BlockParser
  -> Int
  -> Bool
  -> Bool
  -> Located Expression
  -> TokenKind
  -> Bool
  -> Parser (Located Expression, Bool)
parseOperatorTail recovery blockParser minimumPrecedence mayReportAmbiguity crossedLeading left kind newLine = do
  case binaryInfo kind of
    Just (operator, precedence, rightAssociative)
      | precedence >= minimumPrecedence
      , not newLine || continuesAcrossLineBreak kind -> do
      bounded <- withRecursionBudget $ do
        _ <- advanceToken
        let rightMinimum = if rightAssociative then precedence else precedence + 1
        (right, rightCrossedLeading) <-
          parseExpressionTracked recovery blockParser rightMinimum False
        let combined = Located (mergedOrLeft (locatedSpan left) (locatedSpan right))
              (BinaryExpression left operator right)
            crossed = crossedLeading || newLine || rightCrossedLeading
        parseBinaryTail recovery blockParser minimumPrecedence mayReportAmbiguity crossed combined
      pure (maybe (left, crossedLeading) id bounded)
    Just (_, precedence, _)
      | precedence >= minimumPrecedence
      , newLine
      , crossedLeading -> do
      if mayReportAmbiguity then reportAmbiguousLineBreak recovery else pure ()
      case recovery of
        PreserveStatement -> pure ()
        RecoverOwner -> recoverOwnerTail blockParser
      pure (left, crossedLeading)
    _ -> pure (left, crossedLeading)

recoverOwnerTail :: BlockParser -> Parser ()
recoverOwnerTail blockParser = do
  _ <- parseExpressionTracked RecoverOwner blockParser 0 False
  kind <- peekKind
  newLine <- peekStartsLine
  if newLine && isPrefixCapableBinary kind
    then do
      bounded <- withRecursionBudget (recoverOwnerTail blockParser)
      maybe (pure ()) pure bounded
    else pure ()

binaryInfo :: TokenKind -> Maybe (Text, Int, Bool)
binaryInfo kind = case kind of
  Symbol symbol -> operatorInfo symbol
  Keyword KwIn -> Just ("in", 4, False)
  _ -> Nothing

operatorInfo :: SymbolKind -> Maybe (Text, Int, Bool)
operatorInfo symbol = case symbol of
  SymAssign -> binary 0 True
  SymLogicalOr -> binary 1 False
  SymPipe -> binary 1 False
  SymLogicalAnd -> binary 2 False
  SymEqual -> binary 3 False
  SymNotEqual -> binary 3 False
  SymLess -> binary 4 False
  SymLessEqual -> binary 4 False
  SymGreater -> binary 4 False
  SymGreaterEqual -> binary 4 False
  SymCaret -> binary 5 False
  SymLeftShift -> binary 6 False
  SymRightShift -> binary 6 False
  SymAmpersand -> binary 6 False
  SymPlus -> binary 7 False
  SymMinus -> binary 7 False
  SymWrapAdd -> binary 7 False
  SymWrapSubtract -> binary 7 False
  SymSaturatingAdd -> binary 7 False
  SymSaturatingSubtract -> binary 7 False
  SymStar -> binary 8 False
  SymSlash -> binary 8 False
  SymPercent -> binary 8 False
  SymWrapMultiply -> binary 8 False
  SymSaturatingMultiply -> binary 8 False
  _ -> Nothing
 where
  binary precedence rightAssociative = Just (symbolText symbol, precedence, rightAssociative)
