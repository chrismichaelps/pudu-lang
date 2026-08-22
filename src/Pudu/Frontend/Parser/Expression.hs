{-| @Program.Parser.Expression — applies explicit expression precedence -}
module Pudu.Frontend.Parser.Expression
  ( BlockParser
  , parseExpression
  , parseExpressionAt
  ) where

import Data.List.NonEmpty (NonEmpty (..))
import Data.Text (Text)
import Pudu.Frontend.Parser.State
  ( Parser
  , advanceToken
  , currentSpan
  , emitParseError
  , expectIdentifier
  , expectSymbol
  , isSymbol
  , lookaheadKind
  , matchKeyword
  , matchSymbol
  , budgetExhausted
  , expectKeyword
  , peekKind
  , peekStartsLine
  , peekToken
  , withRecursionBudget
  )
import Pudu.Frontend.Parser.Pattern (parsePattern)
import Pudu.Frontend.Syntax.Located (Located (..))
import Pudu.Frontend.Syntax.Tree (Block, Expression (..), Literal (..), MatchArm (..))
import Pudu.Frontend.Token
  ( Keyword (KwAwait, KwCase, KwElse, KwFalse, KwFor, KwIf, KwIn, KwLoop, KwMatch
    , KwMut, KwNull, KwTrue, KwWhile)
  , SymbolKind (..)
  , Token (..)
  , TokenKind (..)
  , symbolText
  )
import Pudu.Source (Span, mergeSpans)

type BlockParser = Parser (Located Block)

parseExpression :: BlockParser -> Parser (Located Expression)
parseExpression blockParser = parseExpressionAt blockParser 0

parseExpressionAt :: BlockParser -> Int -> Parser (Located Expression)
parseExpressionAt blockParser minimumPrecedence = do
  bounded <- withRecursionBudget $ do
    prefix <- parsePrefix blockParser
    postfixed <- parsePostfix blockParser prefix
    parseBinaryTail blockParser minimumPrecedence postfixed
  maybe invalidAtCurrent pure bounded

parsePrefix :: BlockParser -> Parser (Located Expression)
parsePrefix blockParser = do
  token <- peekToken
  case tokenKind token of
    IntegerLiteral value -> literal token (IntegerValue value)
    FloatLiteral value -> literal token (FloatValue value)
    StringLiteral value -> literal token (StringValue value)
    CharLiteral value -> literal token (CharValue value)
    Keyword KwTrue -> literal token (BoolValue True)
    Keyword KwFalse -> literal token (BoolValue False)
    Keyword KwNull -> literal token NullValue
    Keyword KwIf -> parseIf blockParser
    Keyword KwMatch -> parseMatch blockParser
    Keyword KwWhile -> parseWhile blockParser
    Keyword KwLoop -> parseLoop blockParser
    Keyword KwFor -> parseFor blockParser
    Identifier name -> advanceToken >> pure (Located (tokenSpan token) (NameExpression (name :| [])))
    Symbol symbol
      | symbol == SymLeftParen -> parseGrouped blockParser
      | symbol == SymLeftBrace -> blockExpression blockParser
      | symbol `elem` unaryOperators -> parseUnary blockParser token symbol
    _ -> invalidPrefix token

literal :: Token -> Literal -> Parser (Located Expression)
literal token value = do
  _ <- advanceToken
  pure (Located (tokenSpan token) (LiteralExpression value))

blockExpression :: BlockParser -> Parser (Located Expression)
blockExpression blockParser = do
  block <- blockParser
  pure (Located (locatedSpan block) (BlockExpression block))

{-| Parentheses group one expression; a comma makes the same syntax a tuple,
    matching the type grammar's `(T)` and `(T, U)` rule. -}
parseGrouped :: BlockParser -> Parser (Located Expression)
parseGrouped blockParser = do
  opening <- expectSymbol "(" "to start the grouped expression"
  empty <- matchSymbol ")"
  case empty of
    Just closing ->
      pure
        ( Located (mergedOrLeft (tokenSpan opening) (tokenSpan closing))
            (TupleExpression [])
        )
    Nothing -> do
      first <- parseExpression blockParser
      comma <- matchSymbol ","
      case comma of
        Nothing -> do
          closing <- expectSymbol ")" "to close the grouped expression"
          pure first{locatedSpan = mergedOrLeft (tokenSpan opening) (tokenSpan closing)}
        Just _ -> do
          rest <- parseTupleTail blockParser []
          closing <- expectSymbol ")" "to close the tuple expression"
          pure
            ( Located (mergedOrLeft (tokenSpan opening) (tokenSpan closing))
                (TupleExpression (first : rest))
            )

parseTupleTail :: BlockParser -> [Located Expression] -> Parser [Located Expression]
parseTupleTail blockParser reversed = do
  kind <- peekKind
  exhausted <- budgetExhausted
  if isSymbol ")" kind || kind == EndOfFile || exhausted
    then pure (reverse reversed)
    else do
      before <- peekToken
      next <- parseExpression blockParser
      after <- peekToken
      if before == after
        then pure (reverse reversed)
        else do
          comma <- matchSymbol ","
          case comma of
            Nothing -> pure (reverse (next : reversed))
            Just _ -> parseTupleTail blockParser (next : reversed)

parseUnary :: BlockParser -> Token -> SymbolKind -> Parser (Located Expression)
parseUnary blockParser operatorToken operator = do
  _ <- advanceToken
  rendered <- if operator == SymAmpersand
    then maybe "&" (const "&mut") <$> matchKeyword KwMut
    else pure (symbolText operator)
  operand <- parseExpressionAt blockParser 8
  pure (Located (mergedOrLeft (tokenSpan operatorToken) (locatedSpan operand))
    (UnaryExpression rendered operand))

parseIf :: BlockParser -> Parser (Located Expression)
parseIf blockParser = do
  keyword <- advanceToken
  condition <- parseExpression blockParser
  case locatedValue condition of
    InvalidExpression ->
      pure (Located (mergedOrLeft (tokenSpan keyword) (locatedSpan condition)) InvalidExpression)
    _ -> do
      thenBlock <- blockParser
      elseExpression <- parseElse blockParser
      let final = maybe (locatedSpan thenBlock) locatedSpan elseExpression
      pure (Located (mergedOrLeft (tokenSpan keyword) final)
        (IfExpression condition thenBlock elseExpression))

parseElse :: BlockParser -> Parser (Maybe (Located Expression))
parseElse blockParser = do
  elseKeyword <- matchKeyword KwElse
  case elseKeyword of
    Nothing -> pure Nothing
    Just _ -> do
      kind <- peekKind
      case kind of
        Keyword KwIf -> Just <$> parseExpressionAt blockParser 0
        _ | isSymbol "{" kind -> Just <$> blockExpression blockParser
        _ -> do
          spanValue <- currentSpan
          emitParseError "E1042" spanValue "expected if or block after else"
            (Just "add if or a block after else")
          pure (Just (Located spanValue InvalidExpression))

{-| Postfix continuation is line-sensitive per [[grammar/pudu]]: a line-initial
    `(` or `[` starts a new statement, while a line-initial `.`, `?`, or
    `.await` continues a fluent chain. -}
{-| `match` scrutinizes one expression and requires at least one `case` arm.
    Arms are separated by line breaks like every other construct. -}
parseMatch :: BlockParser -> Parser (Located Expression)
parseMatch blockParser = do
  keyword <- advanceToken
  scrutinee <- parseExpression blockParser
  _ <- expectSymbol "{" "to start the match arms"
  arms <- parseArms blockParser []
  closing <- expectSymbol "}" "to close the match arms"
  case arms of
    [] ->
      emitParseError "E1051" (tokenSpan closing) "match requires at least one case arm"
        (Just "add a case arm, or replace the match with an if expression")
    _ -> pure ()
  pure
    ( Located (mergedOrLeft (tokenSpan keyword) (tokenSpan closing))
        (MatchExpression scrutinee arms)
    )

parseArms :: BlockParser -> [Located MatchArm] -> Parser [Located MatchArm]
parseArms blockParser reversed = do
  kind <- peekKind
  exhausted <- budgetExhausted
  if isSymbol "}" kind || kind == EndOfFile || exhausted
    then pure (reverse reversed)
    else do
      before <- peekToken
      arm <- parseArm blockParser
      after <- peekToken
      if before == after
        then advanceToken >> pure (reverse reversed)
        else parseArms blockParser (arm : reversed)

parseArm :: BlockParser -> Parser (Located MatchArm)
parseArm blockParser = do
  keyword <- expectKeyword KwCase "to start a match arm"
  pattern' <- parsePattern
  guard <- parseGuard blockParser
  _ <- expectSymbol "=>" "before the arm body"
  body <- parseArmBody blockParser
  pure
    ( Located (mergedOrLeft (tokenSpan keyword) (locatedSpan body))
        MatchArm{armPattern = pattern', armGuard = guard, armBody = body}
    )

parseGuard :: BlockParser -> Parser (Maybe (Located Expression))
parseGuard blockParser = do
  guardKeyword <- matchKeyword KwIf
  case guardKeyword of
    Nothing -> pure Nothing
    Just _ -> Just <$> parseExpression blockParser

parseArmBody :: BlockParser -> Parser (Located Expression)
parseArmBody blockParser = do
  kind <- peekKind
  if isSymbol "{" kind
    then blockExpression blockParser
    else parseExpression blockParser

{-| `while`, `loop`, and `for` are expressions whose bodies are blocks; their
    value is `()` in this slice, which typing — not parsing — enforces. -}
parseWhile :: BlockParser -> Parser (Located Expression)
parseWhile blockParser = do
  keyword <- advanceToken
  condition <- parseExpression blockParser
  body <- blockParser
  pure
    ( Located (mergedOrLeft (tokenSpan keyword) (locatedSpan body))
        (WhileExpression condition body)
    )

parseLoop :: BlockParser -> Parser (Located Expression)
parseLoop blockParser = do
  keyword <- advanceToken
  body <- blockParser
  pure
    ( Located (mergedOrLeft (tokenSpan keyword) (locatedSpan body))
        (LoopExpression body)
    )

parseFor :: BlockParser -> Parser (Located Expression)
parseFor blockParser = do
  keyword <- advanceToken
  binder <- parsePattern
  _ <- expectKeyword KwIn "between the pattern and the iterated expression"
  iterated <- parseExpression blockParser
  body <- blockParser
  pure
    ( Located (mergedOrLeft (tokenSpan keyword) (locatedSpan body))
        (ForExpression binder iterated body)
    )

parsePostfix :: BlockParser -> Located Expression -> Parser (Located Expression)
parsePostfix blockParser expression = do
  kind <- peekKind
  newLine <- peekStartsLine
  await <- isAwaitPostfix kind
  let lineBreaks = newLine && (isSymbol "(" kind || isSymbol "[" kind)
  if (isPostfixStart kind || await) && not lineBreaks
    then do
      bounded <- withRecursionBudget (parsePostfixStep blockParser expression kind await)
      pure (maybe expression id bounded)
    else pure expression

isAwaitPostfix :: TokenKind -> Parser Bool
isAwaitPostfix kind
  | isSymbol "." kind = (== Keyword KwAwait) <$> lookaheadKind 1
  | otherwise = pure False

{-| Postfix forms bind tighter than every unary and binary operator: call,
    member, index, `?` failure propagation, and `.await`. -}
parsePostfixStep :: BlockParser -> Located Expression -> TokenKind -> Bool -> Parser (Located Expression)
parsePostfixStep blockParser expression kind await
  | await = do
      _ <- advanceToken
      keyword <- advanceToken
      let awaited = Located (mergedOrLeft (locatedSpan expression) (tokenSpan keyword))
            (AwaitExpression expression)
      parsePostfix blockParser awaited
  | isSymbol "?" kind = do
      question <- advanceToken
      let tried = Located (mergedOrLeft (locatedSpan expression) (tokenSpan question))
            (TryExpression expression)
      parsePostfix blockParser tried
  | isSymbol "[" kind = do
      _ <- advanceToken
      index <- parseExpression blockParser
      closing <- expectSymbol "]" "to close the index expression"
      let indexed = Located (mergedOrLeft (locatedSpan expression) (tokenSpan closing))
            (IndexExpression expression index)
      parsePostfix blockParser indexed
  | isSymbol "(" kind = do
      _ <- advanceToken
      (arguments, closing) <- parseArguments blockParser
      case closing of
        Just closingToken -> do
          let call = Located (mergedOrLeft (locatedSpan expression) (tokenSpan closingToken))
                (CallExpression expression arguments)
          parsePostfix blockParser call
        Nothing -> pure (Located (callRecoverySpan expression arguments) InvalidExpression)
  | otherwise = do
      _ <- advanceToken
      member <- expectIdentifier "after ."
      let selection = Located (mergedOrLeft (locatedSpan expression) (locatedSpan member))
            (MemberExpression expression member)
      parsePostfix blockParser selection

isPostfixStart :: TokenKind -> Bool
isPostfixStart kind =
  isSymbol "(" kind || isSymbol "." kind || isSymbol "[" kind || isSymbol "?" kind

parseArguments :: BlockParser -> Parser ([Located Expression], Maybe Token)
parseArguments blockParser = do
  kind <- peekKind
  if isSymbol ")" kind then advanceToken >>= \closing -> pure ([], Just closing)
    else parseExpression blockParser >>= \first -> parseArgumentTail blockParser [first]

parseArgumentTail :: BlockParser -> [Located Expression] -> Parser ([Located Expression], Maybe Token)
parseArgumentTail blockParser reversed = do
  comma <- matchSymbol ","
  case comma of
    Nothing -> do
      closing <- expectSymbol ")" "to close the function arguments"
      pure (reverse reversed, Just closing)
    Just _ -> do
      kind <- peekKind
      if isSymbol ")" kind
        then advanceToken >>= \closing -> pure (reverse reversed, Just closing)
        else do
          bounded <- withRecursionBudget $ do
            before <- peekToken
            next <- parseExpression blockParser
            after <- peekToken
            if before == after
              then pure (reverse reversed, Nothing)
              else parseArgumentTail blockParser (next : reversed)
          pure (maybe (reverse reversed, Nothing) id bounded)

callRecoverySpan :: Located Expression -> [Located Expression] -> Span
callRecoverySpan expression = foldl' mergedOrLeft (locatedSpan expression) . map locatedSpan

parseBinaryTail :: BlockParser -> Int -> Located Expression -> Parser (Located Expression)
parseBinaryTail blockParser minimumPrecedence left = do
  kind <- peekKind
  newLine <- peekStartsLine
  case binaryInfo kind of
    Just (operator, precedence, rightAssociative)
      | precedence >= minimumPrecedence
      , not newLine -> do
      bounded <- withRecursionBudget $ do
        _ <- advanceToken
        let rightMinimum = if rightAssociative then precedence else precedence + 1
        right <- parseExpressionAt blockParser rightMinimum
        let combined = Located (mergedOrLeft (locatedSpan left) (locatedSpan right))
              (BinaryExpression left operator right)
        parseBinaryTail blockParser minimumPrecedence combined
      pure (maybe left id bounded)
    _ -> pure left

binaryInfo :: TokenKind -> Maybe (Text, Int, Bool)
binaryInfo kind = case kind of
  Symbol symbol -> operatorInfo symbol
  _ -> Nothing

operatorInfo :: SymbolKind -> Maybe (Text, Int, Bool)
operatorInfo symbol = case symbol of
  SymAssign -> binary 0 True
  SymLogicalOr -> binary 1 False
  SymLogicalAnd -> binary 2 False
  SymEqual -> binary 3 False
  SymNotEqual -> binary 3 False
  SymLess -> binary 4 False
  SymLessEqual -> binary 4 False
  SymGreater -> binary 4 False
  SymGreaterEqual -> binary 4 False
  SymRangeExclusive -> binary 5 False
  SymRangeInclusive -> binary 5 False
  SymPlus -> binary 6 False
  SymMinus -> binary 6 False
  SymWrapAdd -> binary 6 False
  SymWrapSubtract -> binary 6 False
  SymSaturatingAdd -> binary 6 False
  SymSaturatingSubtract -> binary 6 False
  SymStar -> binary 7 False
  SymSlash -> binary 7 False
  SymPercent -> binary 7 False
  SymWrapMultiply -> binary 7 False
  SymSaturatingMultiply -> binary 7 False
  _ -> Nothing
 where
  binary precedence rightAssociative = Just (symbolText symbol, precedence, rightAssociative)

invalidPrefix :: Token -> Parser (Located Expression)
invalidPrefix token = do
  emitParseError "E1040" (tokenSpan token) "expected expression"
    (Just "start with a literal, name, (, {, if, or unary operator")
  case tokenKind token of
    EndOfFile -> pure ()
    kind | isRecoveryBoundary kind -> pure ()
    _ -> advanceToken >> pure ()
  pure (Located (tokenSpan token) InvalidExpression)

invalidAtCurrent :: Parser (Located Expression)
invalidAtCurrent = currentSpan >>= \spanValue -> pure (Located spanValue InvalidExpression)

unaryOperators :: [SymbolKind]
unaryOperators = [SymBang, SymMinus, SymAmpersand]

isRecoveryBoundary :: TokenKind -> Bool
isRecoveryBoundary kind = any (`isSymbol` kind) [",", ")", "]", "}"]

mergedOrLeft :: Span -> Span -> Span
mergedOrLeft left right = maybe left id (mergeSpans left right)
