{-| @Program.Parser.Expression.Postfix — parses what may follow an operand -}
module Pudu.Frontend.Parser.Expression.Postfix
  ( callRecoverySpan
  , isPostfixStart
  , parsePostfix
  ) where

import Data.Char (isUpper)
import qualified Data.Text as Text
import Pudu.Frontend.Parser.Expression.Control (ExpressionParsers (..))
import Pudu.Frontend.Parser.Expression.Recovery (mergedOrLeft)
import Pudu.Frontend.Parser.State
  ( BlockParser
  , Parser
  , advanceToken
  , expectIdentifier
  , expectSymbol
  , isSymbol
  , lookaheadKind
  , matchSymbol
  , matchingBracketDistance
  , peekKind
  , peekStartsLine
  , peekToken
  , withRecords
  , withRecursionBudget
  )
import Pudu.Frontend.Parser.Type (parseTypeSyntax)
import Pudu.Frontend.Syntax.Located (Located (..))
import Pudu.Frontend.Syntax.Tree (Expression (..), TypeSyntax)
import Pudu.Frontend.Token
  ( Keyword (KwAsync, KwAwait, KwFn)
  , SymbolKind (..)
  , Token (..)
  , TokenKind (..)
  )
import Pudu.Source (Span)

parsePostfix :: ExpressionParsers -> BlockParser -> Located Expression -> Parser (Located Expression)
parsePostfix parsers blockParser expression = do
  kind <- peekKind
  newLine <- peekStartsLine
  await <- isAwaitPostfix kind
  let lineBreaks = newLine && (isSymbol "(" kind || isSymbol "[" kind)
  if (isPostfixStart kind || await) && not lineBreaks
    then do
      bounded <- withRecursionBudget (parsePostfixStep parsers blockParser expression kind await)
      pure (maybe expression id bounded)
    else pure expression

isAwaitPostfix :: TokenKind -> Parser Bool
isAwaitPostfix kind
  | isSymbol "." kind = (== Keyword KwAwait) <$> lookaheadKind 1
  | otherwise = pure False

{-| Postfix forms bind tighter than every unary and binary operator: call,
    member, index, `?` failure propagation, and `.await`. -}
parsePostfixStep :: ExpressionParsers -> BlockParser -> Located Expression -> TokenKind -> Bool -> Parser (Located Expression)
parsePostfixStep parsers blockParser expression kind await
  | await = do
      _ <- advanceToken
      keyword <- advanceToken
      let awaited = Located (mergedOrLeft (locatedSpan expression) (tokenSpan keyword))
            (AwaitExpression expression)
      parsePostfix parsers blockParser awaited
  | isSymbol "?" kind = do
      question <- advanceToken
      let tried = Located (mergedOrLeft (locatedSpan expression) (tokenSpan question))
            (TryExpression expression)
      parsePostfix parsers blockParser tried
  | isSymbol "[" kind = do
      typed <- bracketOpensTypeArguments
      if typed then parseTypeArguments parsers blockParser expression else do
        _ <- advanceToken
        index <- withRecords (expressionOf parsers blockParser)
        closing <- expectSymbol "]" "to close the index expression"
        let indexed = Located (mergedOrLeft (locatedSpan expression) (tokenSpan closing))
              (IndexExpression expression index)
        parsePostfix parsers blockParser indexed
  | isSymbol "(" kind = do
      _ <- advanceToken
      (arguments, closing) <- parseArguments parsers blockParser
      case closing of
        Just closingToken -> do
          let call = Located (mergedOrLeft (locatedSpan expression) (tokenSpan closingToken))
                (CallExpression expression arguments)
          parsePostfix parsers blockParser call
        Nothing -> pure (Located (callRecoverySpan expression arguments) InvalidExpression)
  | otherwise = do
      _ <- advanceToken
      member <- expectIdentifier "after ."
      let selection = Located (mergedOrLeft (locatedSpan expression) (locatedSpan member))
            (MemberExpression expression member)
      parsePostfix parsers blockParser selection

{-| Whether the `[` here opens a type-argument list rather than an index.

    A type-argument list is always applied, so a closing `]` followed by `(`
    decides it: `convertInteger[UInt8](300)` names a type, `handlers[index](x)`
    reads one out of an array and calls it. The second form is the one that
    loses, and a reader who means it writes `(handlers[index])(x)`.

    What the brackets contain narrows it further: only a token that could begin
    a type is admitted, and an identifier counts only when it is capitalised.
    An index by a variable or a literal is therefore never mistaken. What
    remains is an index by a capitalised constant that is immediately called —
    `handlers[DEFAULT](value)` — which is rare and which parentheses settle. -}
bracketOpensTypeArguments :: Parser Bool
bracketOpensTypeArguments = do
  opens <- opensWithType <$> lookaheadKind 1
  if not opens then pure False else do
    closing <- matchingBracketDistance
    case closing of
      Nothing -> pure False
      Just distance -> isSymbol "(" <$> lookaheadKind (distance + 1)

{-| Whether a token could begin a written type.

    An identifier counts only when it is capitalised, which [[grammar/pudu]]
    already requires of every type name and forbids of every value name. So
    `handlers[index](value)` reads an element and calls it, while
    `convert[UInt8](value)` names a type — and neither reader has to think about
    it. -}
opensWithType :: TokenKind -> Bool
opensWithType kind = case kind of
  Identifier name -> maybe False (isUpper . fst) (Text.uncons name)
  Symbol symbol -> symbol == SymAmpersand || symbol == SymLeftParen
  Keyword KwFn -> True
  Keyword KwAsync -> True
  _ -> False

{-| Parse `name[Type, Type]`, the explicit type arguments of a call.

    Inference settles a type parameter from the arguments wherever it can. This
    is for where it cannot: a function whose parameter appears only in its
    result has nothing to infer from, and before this the only way to pin one
    was to pass a value of the type purely as an example. -}
parseTypeArguments :: ExpressionParsers -> BlockParser -> Located Expression -> Parser (Located Expression)
parseTypeArguments parsers blockParser expression = do
  _ <- advanceToken
  arguments <- parseTypeArgumentList []
  closing <- expectSymbol "]" "to close the type arguments"
  let applied = Located (mergedOrLeft (locatedSpan expression) (tokenSpan closing))
        (TypeApplication expression arguments)
  parsePostfix parsers blockParser applied

parseTypeArgumentList :: [Located TypeSyntax] -> Parser [Located TypeSyntax]
parseTypeArgumentList reversed = do
  closing <- isSymbol "]" <$> peekKind
  if closing
    then pure (reverse reversed)
    else do
      argument <- parseTypeSyntax
      let extended = argument : reversed
      separator <- matchSymbol ","
      case separator of
        Just _ -> parseTypeArgumentList extended
        Nothing -> pure (reverse extended)

isPostfixStart :: TokenKind -> Bool
isPostfixStart kind =
  isSymbol "(" kind || isSymbol "." kind || isSymbol "[" kind || isSymbol "?" kind

parseArguments :: ExpressionParsers -> BlockParser -> Parser ([Located Expression], Maybe Token)
parseArguments parsers blockParser = do
  kind <- peekKind
  if isSymbol ")" kind then advanceToken >>= \closing -> pure ([], Just closing)
    else withRecords (expressionOf parsers blockParser) >>= \first -> parseArgumentTail parsers blockParser [first]

parseArgumentTail :: ExpressionParsers -> BlockParser -> [Located Expression] -> Parser ([Located Expression], Maybe Token)
parseArgumentTail parsers blockParser reversed = do
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
            next <- withRecords (expressionOf parsers blockParser)
            after <- peekToken
            if before == after
              then pure (reverse reversed, Nothing)
              else parseArgumentTail parsers blockParser (next : reversed)
          pure (maybe (reverse reversed, Nothing) id bounded)

callRecoverySpan :: Located Expression -> [Located Expression] -> Span
callRecoverySpan expression = foldl mergedOrLeft (locatedSpan expression) . map locatedSpan
