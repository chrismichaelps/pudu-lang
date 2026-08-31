{-| @Program.Parser.Expression.Aggregate — parses names, records, and literals -}
module Pudu.Frontend.Parser.Expression.Aggregate
  ( blockExpression
  , literal
  , parseArrayLiteral
  , parseSetLiteral
  , parseGrouped
  , parseNameOrRecord
  ) where

import Data.Char (isUpper)
import Data.List.NonEmpty (NonEmpty (..))
import Data.Text (Text)
import qualified Data.Text as Text
import Pudu.Frontend.Parser.Expression.Control (ExpressionParsers (..))
import Pudu.Frontend.Parser.Expression.Recovery (mergedOrLeft)
import Pudu.Frontend.Parser.Name (parseModuleName)
import Pudu.Frontend.Parser.State
  ( BlockParser
  , Parser
  , advanceToken
  , budgetExhausted
  , expectIdentifier
  , expectSymbol
  , isSymbol
  , lookaheadKind
  , matchSymbol
  , peekKind
  , peekToken
  , recordsAdmitted
  , withRecords
  , withRecursionBudget
  )
import Pudu.Frontend.Syntax.Located (Located (..))
import Pudu.Frontend.Syntax.Tree
  ( Expression (..)
  , FieldInit (..)
  , Literal (..)
  )
import Pudu.Frontend.Token (Token (..), TokenKind (..))

{-| An uppercase name directly followed by `{` builds a record, when records are
    admitted here; every other name is a plain reference. -}
parseNameOrRecord :: ExpressionParsers -> BlockParser -> Token -> Text -> Parser (Located Expression)
parseNameOrRecord parsers blockParser token name
  | not (startsUpper name) = do
      macroCall <- macroFollows
      if macroCall then parseMacroCall parsers blockParser token name else plainName
  | otherwise = do
      admitted <- recordsAdmitted
      opensRecord <- recordFollows
      if admitted && opensRecord
        then parseRecordExpression parsers blockParser
        else plainName
 where
  plainName = advanceToken >> pure (Located (tokenSpan token) (NameExpression (name :| [])))

{-| A record construction may be introduced by a qualified path, so the scan
    walks `Name.Name` segments before deciding whether a `{` follows. The walk
    is bounded by the path length the name grammar admits. -}
recordFollows :: Parser Bool
recordFollows = walk 1 (0 :: Int)
 where
  walk offset segments
    | segments > 64 = pure False
    | otherwise = do
        following <- lookaheadKind offset
        if isSymbol "." following
          then do
            segment <- lookaheadKind (offset + 1)
            case segment of
              Identifier _ -> walk (offset + 2) (segments + 1)
              _ -> pure False
          else pure (isSymbol "{" following)

{-| A macro call is written `name!(...)`, so expansion is visible at the call
    rather than depending on knowing which names are macros. -}
macroFollows :: Parser Bool
macroFollows = do
  bang <- lookaheadKind 1
  opening <- lookaheadKind 2
  pure (isSymbol "!" bang && isSymbol "(" opening)

parseMacroCall :: ExpressionParsers -> BlockParser -> Token -> Text -> Parser (Located Expression)
parseMacroCall parsers blockParser token name = do
  _ <- advanceToken
  _ <- advanceToken
  _ <- expectSymbol "(" "before the macro arguments"
  arguments <- parseMacroArguments parsers blockParser []
  closing <- expectSymbol ")" "to close the macro arguments"
  pure
    ( Located (mergedOrLeft (tokenSpan token) (tokenSpan closing))
        (MacroCall (Located (tokenSpan token) name) arguments)
    )

parseMacroArguments :: ExpressionParsers -> BlockParser -> [Located Expression] -> Parser [Located Expression]
parseMacroArguments parsers blockParser reversed = do
  kind <- peekKind
  exhausted <- budgetExhausted
  if isSymbol ")" kind || kind == EndOfFile || exhausted
    then pure (reverse reversed)
    else do
      before <- peekToken
      argument <- withRecords (parseArgumentSyntax parsers blockParser)
      after <- peekToken
      if before == after
        then pure (reverse reversed)
        else do
          comma <- matchSymbol ","
          case comma of
            Nothing -> pure (reverse (argument : reversed))
            Just _ -> parseMacroArguments parsers blockParser (argument : reversed)

{-| A macro argument may be a block, which an ordinary expression position would
    read as a record or a nested scope; parsing it here keeps `block` parameters
    writable as `{ ... }`. -}
parseArgumentSyntax :: ExpressionParsers -> BlockParser -> Parser (Located Expression)
parseArgumentSyntax parsers blockParser = do
  kind <- peekKind
  if isSymbol "{" kind
    then blockExpression parsers blockParser
    else expressionOf parsers blockParser

startsUpper :: Text -> Bool
startsUpper value = maybe False (isUpper . fst) (Text.uncons value)

parseRecordExpression :: ExpressionParsers -> BlockParser -> Parser (Located Expression)
parseRecordExpression parsers blockParser = do
  path <- parseModuleName
  _ <- expectSymbol "{" "to start the record fields"
  fields <- withRecords (parseFieldInits parsers blockParser [])
  closing <- expectSymbol "}" "to close the record fields"
  pure
    ( Located (mergedOrLeft (locatedSpan path) (tokenSpan closing))
        (RecordExpression (locatedValue path) fields)
    )

parseFieldInits :: ExpressionParsers -> BlockParser -> [Located FieldInit] -> Parser [Located FieldInit]
parseFieldInits parsers blockParser reversed = do
  kind <- peekKind
  exhausted <- budgetExhausted
  if isSymbol "}" kind || kind == EndOfFile || exhausted
    then pure (reverse reversed)
    else do
      before <- peekToken
      field <- parseFieldInit parsers blockParser
      after <- peekToken
      if before == after
        then pure (reverse reversed)
        else do
          comma <- matchSymbol ","
          case comma of
            Nothing -> pure (reverse (field : reversed))
            Just _ -> parseFieldInits parsers blockParser (field : reversed)

{-| A field written without `:` takes the binding with its own name, mirroring
    the record pattern's shorthand. -}
parseFieldInit :: ExpressionParsers -> BlockParser -> Parser (Located FieldInit)
parseFieldInit parsers blockParser = do
  name <- expectIdentifier "for the record field"
  colon <- matchSymbol ":"
  value <- case colon of
    Nothing -> pure Nothing
    Just _ -> Just <$> expressionOf parsers blockParser
  pure
    ( Located (maybe (locatedSpan name) (mergedOrLeft (locatedSpan name) . locatedSpan) value)
        FieldInit{fieldInitName = name, fieldInitValue = value}
    )

literal :: Token -> Literal -> Parser (Located Expression)
literal token value = do
  _ <- advanceToken
  pure (Located (tokenSpan token) (LiteralExpression value))

blockExpression :: ExpressionParsers -> BlockParser -> Parser (Located Expression)
blockExpression _ blockParser = do
  block <- blockParser
  pure (Located (locatedSpan block) (BlockExpression block))

{-| Parentheses group one expression; a comma makes the same syntax a tuple,
    matching the type grammar's `(T)` and `(T, U)` rule. -}
parseGrouped :: ExpressionParsers -> BlockParser -> Parser (Located Expression)
parseGrouped parsers blockParser = do
  opening <- expectSymbol "(" "to start the grouped expression"
  empty <- matchSymbol ")"
  case empty of
    Just closing ->
      pure
        ( Located (mergedOrLeft (tokenSpan opening) (tokenSpan closing))
            (TupleExpression [])
        )
    Nothing -> do
      first <- expressionOf parsers blockParser
      comma <- matchSymbol ","
      case comma of
        Nothing -> do
          closing <- expectSymbol ")" "to close the grouped expression"
          pure first{locatedSpan = mergedOrLeft (tokenSpan opening) (tokenSpan closing)}
        Just _ -> do
          rest <- parseTupleTail parsers blockParser []
          closing <- expectSymbol ")" "to close the tuple expression"
          pure
            ( Located (mergedOrLeft (tokenSpan opening) (tokenSpan closing))
                (TupleExpression (first : rest))
            )

parseTupleTail :: ExpressionParsers -> BlockParser -> [Located Expression] -> Parser [Located Expression]
parseTupleTail parsers blockParser reversed = do
  kind <- peekKind
  exhausted <- budgetExhausted
  if isSymbol ")" kind || kind == EndOfFile || exhausted
    then pure (reverse reversed)
    else do
      before <- peekToken
      next <- expressionOf parsers blockParser
      after <- peekToken
      if before == after
        then pure (reverse reversed)
        else do
          comma <- matchSymbol ","
          case comma of
            Nothing -> pure (reverse (next : reversed))
            Just _ -> parseTupleTail parsers blockParser (next : reversed)

{-| An array literal `[a, b, c]` admits expressions separated by commas with an
    optional trailing comma. `[]` is the empty array. Records are admitted inside
    the bracketed context so `Some{value: 1}` works as an element. -}
parseArrayLiteral :: ExpressionParsers -> BlockParser -> Parser (Located Expression)
parseArrayLiteral parsers blockParser = do
  opening <- expectSymbol "[" "to start the array literal"
  empty <- matchSymbol "]"
  case empty of
    Just closing ->
      pure
        ( Located (mergedOrLeft (tokenSpan opening) (tokenSpan closing))
            (ArrayExpression [])
        )
    Nothing -> do
      first <- withRecords (expressionOf parsers blockParser)
      rest <- parseArrayTail parsers blockParser []
      closing <- expectSymbol "]" "to close the array literal"
      pure
        ( Located (mergedOrLeft (tokenSpan opening) (tokenSpan closing))
            (ArrayExpression (first : rest))
        )

parseArrayTail :: ExpressionParsers -> BlockParser -> [Located Expression] -> Parser [Located Expression]
parseArrayTail parsers blockParser reversed = do
  comma <- matchSymbol ","
  case comma of
    Nothing -> pure (reverse reversed)
    Just _ -> do
      kind <- peekKind
      if isSymbol "]" kind
        then pure (reverse reversed)
        else do
          bounded <- withRecursionBudget $ do
            before <- peekToken
            next <- withRecords (expressionOf parsers blockParser)
            after <- peekToken
            if before == after
              then pure (reverse reversed, True)
              else do
                rest <- parseArrayTail parsers blockParser (next : reversed)
                pure (rest, False)
          pure (maybe (reverse reversed) fst bounded)

{-| A Set literal `#{a, b, c}` retains every member expression in source
    order. The evaluator, not the parser, collapses duplicate values after all
    of those expressions have run. -}
parseSetLiteral :: ExpressionParsers -> BlockParser -> Parser (Located Expression)
parseSetLiteral parsers blockParser = do
  hash <- expectSymbol "#" "to start the Set literal"
  _ <- expectSymbol "{" "after # in the Set literal"
  empty <- matchSymbol "}"
  case empty of
    Just closing ->
      pure
        ( Located (mergedOrLeft (tokenSpan hash) (tokenSpan closing))
            (SetExpression [])
        )
    Nothing -> do
      first <- withRecords (expressionOf parsers blockParser)
      rest <- parseSetTail parsers blockParser []
      closing <- expectSymbol "}" "to close the Set literal"
      pure
        ( Located (mergedOrLeft (tokenSpan hash) (tokenSpan closing))
            (SetExpression (first : rest))
        )

parseSetTail :: ExpressionParsers -> BlockParser -> [Located Expression] -> Parser [Located Expression]
parseSetTail parsers blockParser reversed = do
  comma <- matchSymbol ","
  case comma of
    Nothing -> pure (reverse reversed)
    Just _ -> do
      kind <- peekKind
      if isSymbol "}" kind
        then pure (reverse reversed)
        else do
          bounded <- withRecursionBudget $ do
            before <- peekToken
            next <- withRecords (expressionOf parsers blockParser)
            after <- peekToken
            if before == after
              then pure (reverse reversed, True)
              else do
                rest <- parseSetTail parsers blockParser (next : reversed)
                pure (rest, False)
          pure (maybe (reverse reversed) fst bounded)
