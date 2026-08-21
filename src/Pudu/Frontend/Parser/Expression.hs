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
  , peekKind
  , peekToken
  , withRecursionBudget
  )
import Pudu.Frontend.Syntax.Located (Located (..))
import Pudu.Frontend.Syntax.Tree (Block, Expression (..), Literal (..))
import Pudu.Frontend.Token
  ( Keyword (KwAwait, KwElse, KwFalse, KwIf, KwMut, KwNull, KwTrue)
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

parseGrouped :: BlockParser -> Parser (Located Expression)
parseGrouped blockParser = do
  opening <- expectSymbol "(" "to start the grouped expression"
  expression <- parseExpression blockParser
  closing <- expectSymbol ")" "to close the grouped expression"
  pure expression{locatedSpan = mergedOrLeft (tokenSpan opening) (tokenSpan closing)}

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

parsePostfix :: BlockParser -> Located Expression -> Parser (Located Expression)
parsePostfix blockParser expression = do
  kind <- peekKind
  reserved <- isReservedPostfix kind
  if reserved
    then parseReservedPostfix expression kind
    else if isPostfixStart kind
      then do
        bounded <- withRecursionBudget (parsePostfixStep blockParser expression kind)
        pure (maybe expression id bounded)
      else pure expression

isReservedPostfix :: TokenKind -> Parser Bool
isReservedPostfix kind
  | isSymbol "[" kind || isSymbol "?" kind = pure True
  | isSymbol "." kind = (== Keyword KwAwait) <$> lookaheadKind 1
  | otherwise = pure False

parseReservedPostfix :: Located Expression -> TokenKind -> Parser (Located Expression)
parseReservedPostfix expression kind = do
  first <- advanceToken
  final <- if isSymbol "." kind then advanceToken else pure first
  let diagnosticSpan = mergedOrLeft (tokenSpan first) (tokenSpan final)
      expressionSpan = mergedOrLeft (locatedSpan expression) (tokenSpan final)
  emitParseError "E1043" diagnosticSpan "postfix expression form is reserved"
    (Just "indexing, failure propagation, and await syntax enter in later semantic slices")
  pure (Located expressionSpan InvalidExpression)

parsePostfixStep :: BlockParser -> Located Expression -> TokenKind -> Parser (Located Expression)
parsePostfixStep blockParser expression kind
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
isPostfixStart kind = isSymbol "(" kind || isSymbol "." kind

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
  case binaryInfo kind of
    Just (operator, precedence, rightAssociative) | precedence >= minimumPrecedence -> do
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
