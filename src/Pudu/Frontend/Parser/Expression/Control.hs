{-| @Program.Parser.Expression.Control — parses the branching and looping forms -}
module Pudu.Frontend.Parser.Expression.Control
  ( ExpressionParsers (..)
  , parseFor
  , parseIf
  , parseLabelled
  , parseLoop
  , parseMatch
  , parseWhile
  , patternCanFail
  ) where

import Data.Text (Text)
import Pudu.Frontend.Parser.Expression.Recovery (labelWithoutLoop, mergedOrLeft)
import Pudu.Frontend.Parser.Pattern (parsePattern)
import Pudu.Frontend.Parser.State
  ( BlockParser
  , Parser
  , advanceToken
  , budgetExhausted
  , expectKeyword
  , expectSymbol
  , isSymbol
  , matchKeyword
  , peekKind
  , currentSpan
  , emitParseError
  , expectIdentifier
  , peekToken
  )
import Pudu.Frontend.Syntax.Located (Located (..))
import Pudu.Frontend.Syntax.Tree
  ( Expression (..)
  , FieldPattern (..)
  , MatchArm (..)
  , Pattern (..)
  )
import Pudu.Frontend.Token
  ( Keyword (KwCase, KwElse, KwFor, KwIf, KwIn, KwLet, KwLoop, KwWhile)
  , Token (..)
  , TokenKind (..)
  )

{-| @Control.ExpressionParsers — the two ways this module reads an expression.

    Control forms contain expressions and expressions contain control forms, so
    one of the two directions has to be a capability rather than an import. The
    expression parser hands its own entry points in, exactly as it already hands
    in the block parser, and the module cycle never forms.

    The two differ in one rule: a scrutinee refuses a record construction,
    because `if READY { ... }` would otherwise be ambiguous with the block that
    follows it. -}
data ExpressionParsers = ExpressionParsers
  { expressionOf :: BlockParser -> Parser (Located Expression)
  , scrutineeOf :: BlockParser -> Parser (Located Expression)
  , expressionAt :: BlockParser -> Int -> Parser (Located Expression)
  }

{-| A block standing where an expression is wanted, which is what an `else`
    branch and a match arm both are. -}
blockExpression :: BlockParser -> Parser (Located Expression)
blockExpression blockParser = do
  block <- blockParser
  pure (Located (locatedSpan block) (BlockExpression block))


parseIf :: ExpressionParsers -> BlockParser -> Parser (Located Expression)
parseIf parsers blockParser = do
  keyword <- advanceToken
  patternCondition <- matchKeyword KwLet
  case patternCondition of
    Just _ -> parseIfLet parsers blockParser keyword
    Nothing -> parseBooleanIf parsers blockParser keyword

parseBooleanIf
  :: ExpressionParsers -> BlockParser -> Token -> Parser (Located Expression)
parseBooleanIf parsers blockParser keyword = do
  condition <- scrutineeOf parsers blockParser
  case locatedValue condition of
    InvalidExpression ->
      pure (Located (mergedOrLeft (tokenSpan keyword) (locatedSpan condition)) InvalidExpression)
    _ -> do
      thenBlock <- blockParser
      elseExpression <- parseElse parsers blockParser
      let final = maybe (locatedSpan thenBlock) locatedSpan elseExpression
      pure (Located (mergedOrLeft (tokenSpan keyword) final)
        (IfExpression condition thenBlock elseExpression))

parseIfLet
  :: ExpressionParsers -> BlockParser -> Token -> Parser (Located Expression)
parseIfLet parsers blockParser keyword = do
  pattern' <- parsePattern
  case locatedValue pattern' of
    InvalidPattern -> pure ()
    value | patternCanFail value -> pure ()
    _ ->
      emitParseError "E1056" (locatedSpan pattern') "if let pattern always matches"
        (Just "use let for an unconditional binding, or choose a pattern that can fail")
  _ <- expectSymbol "=" "between the pattern and its value"
  subject <- scrutineeOf parsers blockParser
  thenBlock <- blockParser
  elseExpression <- parseElse parsers blockParser
  let final = maybe (locatedSpan thenBlock) locatedSpan elseExpression
  pure
    ( Located (mergedOrLeft (tokenSpan keyword) final)
        (IfLetExpression pattern' subject thenBlock elseExpression)
    )

patternCanFail :: Pattern -> Bool
patternCanFail pattern' = case pattern' of
  WildcardPattern -> False
  BindingPattern _ -> False
  LiteralPattern _ -> True
  RangePattern{} -> True
  TuplePattern members -> any (patternCanFail . locatedValue) members
  ConstructorPattern{} -> True
  RecordPattern path fields _ ->
    maybe (any fieldCanFail fields) (const True) path
  AlternativePattern alternatives -> all (patternCanFail . locatedValue) alternatives
  InvalidPattern -> True
 where
  fieldCanFail (Located _ field) =
    maybe False (patternCanFail . locatedValue) (fieldPatternValue field)

parseElse :: ExpressionParsers -> BlockParser -> Parser (Maybe (Located Expression))
parseElse parsers blockParser = do
  elseKeyword <- matchKeyword KwElse
  case elseKeyword of
    Nothing -> pure Nothing
    Just _ -> do
      kind <- peekKind
      case kind of
        Keyword KwIf -> Just <$> expressionAt parsers blockParser 0
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
parseMatch :: ExpressionParsers -> BlockParser -> Parser (Located Expression)
parseMatch parsers blockParser = do
  keyword <- advanceToken
  scrutinee <- scrutineeOf parsers blockParser
  _ <- expectSymbol "{" "to start the match arms"
  arms <- parseArms parsers blockParser []
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

parseArms :: ExpressionParsers -> BlockParser -> [Located MatchArm] -> Parser [Located MatchArm]
parseArms parsers blockParser reversed = do
  kind <- peekKind
  exhausted <- budgetExhausted
  if isSymbol "}" kind || kind == EndOfFile || exhausted
    then pure (reverse reversed)
    else do
      before <- peekToken
      arm <- parseArm parsers blockParser
      after <- peekToken
      if before == after
        then advanceToken >> pure (reverse reversed)
        else parseArms parsers blockParser (arm : reversed)

parseArm :: ExpressionParsers -> BlockParser -> Parser (Located MatchArm)
parseArm parsers blockParser = do
  keyword <- expectKeyword KwCase "to start a match arm"
  pattern' <- parsePattern
  guard <- parseGuard parsers blockParser
  _ <- expectSymbol "=>" "before the arm body"
  body <- parseArmBody parsers blockParser
  pure
    ( Located (mergedOrLeft (tokenSpan keyword) (locatedSpan body))
        MatchArm{armPattern = pattern', armGuard = guard, armBody = body}
    )

parseGuard :: ExpressionParsers -> BlockParser -> Parser (Maybe (Located Expression))
parseGuard parsers blockParser = do
  guardKeyword <- matchKeyword KwIf
  case guardKeyword of
    Nothing -> pure Nothing
    Just _ -> Just <$> expressionOf parsers blockParser

parseArmBody :: ExpressionParsers -> BlockParser -> Parser (Located Expression)
parseArmBody parsers blockParser = do
  kind <- peekKind
  if isSymbol "{" kind
    then blockExpression blockParser
    else expressionOf parsers blockParser

{-| Parse a labelled loop.

    A label is written `@name` before the loop it names, and `break @name`
    leaves that loop from inside any number of nested ones. The sigil is what
    makes `break @outer value` readable at all: with bare names, `break outer`
    could equally be a label or the value `outer`, and no lookahead settles it,
    so a reader would have to know which loops were labelled to know what the
    statement did.

    Only a loop may be labelled. Naming anything else would promise a `break`
    that has nowhere to go. -}
parseLabelled :: ExpressionParsers -> BlockParser -> Parser (Located Expression)
parseLabelled parsers blockParser = do
  sigil <- advanceToken
  name <- expectIdentifier "after @ to name the loop"
  let label = Just name
      start = tokenSpan sigil
  kind <- peekKind
  case kind of
    Keyword KwLoop -> extend start <$> parseLoop parsers blockParser label
    Keyword KwWhile -> extend start <$> parseWhile parsers blockParser label
    Keyword KwFor -> extend start <$> parseFor parsers blockParser label
    _ -> do
      token <- peekToken
      labelWithoutLoop token
 where
  extend start (Located here value) = Located (mergedOrLeft start here) value

{-| `while`, `loop`, and `for` are expressions whose bodies are blocks. `loop`
    takes the type of what its `break` statements carry; the other two are `()`,
    because a loop with a condition can finish without ever reaching a `break`
    and would then have no value to give. Typing enforces that, not parsing. -}
parseWhile :: ExpressionParsers -> BlockParser -> Maybe (Located Text) -> Parser (Located Expression)
parseWhile parsers blockParser label = do
  keyword <- advanceToken
  condition <- scrutineeOf parsers blockParser
  body <- blockParser
  pure
    ( Located (mergedOrLeft (tokenSpan keyword) (locatedSpan body))
        (WhileExpression label condition body)
    )

parseLoop :: ExpressionParsers -> BlockParser -> Maybe (Located Text) -> Parser (Located Expression)
parseLoop _ blockParser label = do
  keyword <- advanceToken
  body <- blockParser
  pure
    ( Located (mergedOrLeft (tokenSpan keyword) (locatedSpan body))
        (LoopExpression label body)
    )

parseFor :: ExpressionParsers -> BlockParser -> Maybe (Located Text) -> Parser (Located Expression)
parseFor parsers blockParser label = do
  keyword <- advanceToken
  binder <- parsePattern
  _ <- expectKeyword KwIn "between the pattern and the iterated expression"
  iterated <- scrutineeOf parsers blockParser
  body <- blockParser
  pure
    ( Located (mergedOrLeft (tokenSpan keyword) (locatedSpan body))
        (ForExpression label binder iterated body)
    )
