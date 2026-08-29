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
  ( Keyword (KwAsync, KwFalse, KwFn, KwFor, KwIf, KwLoop
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
      | otherwise -> parseScope blockParser
    Keyword KwLoop -> parseLoop controlParsers blockParser Nothing
    Keyword KwFor -> parseFor controlParsers blockParser Nothing
    Identifier name -> parseNameOrRecord controlParsers blockParser token name
    Symbol SymAt -> parseLabelled controlParsers blockParser
    Symbol symbol
      | symbol == SymLeftParen -> withRecords (parseGrouped controlParsers blockParser)
      | symbol == SymLeftBrace -> blockExpression controlParsers blockParser
      | symbol == SymLeftBracket -> parseArrayLiteral controlParsers blockParser
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
  parameters <- parseLambdaParameters []
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

{-| A literal's parameters: a name and an optional type, separated by commas. -}
parseLambdaParameters :: [Located Parameter] -> Parser [Located Parameter]
parseLambdaParameters reversed = do
  closing <- isSymbol ")" <$> peekKind
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
        Just _ -> parseLambdaParameters extended
        Nothing -> pure (reverse extended)

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
  SymRangeExclusive -> binary 5 False
  SymRangeInclusive -> binary 5 False
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
