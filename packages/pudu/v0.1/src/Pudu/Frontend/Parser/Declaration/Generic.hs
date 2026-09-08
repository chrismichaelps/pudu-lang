{-| @Type.Parser.Declaration.Generic — parses shared generic syntax -}
module Pudu.Frontend.Parser.Declaration.Generic
  ( parseTypeParams
  , parseWhereClause
  ) where

import Pudu.Frontend.Parser.Name (expectUpperIdentifier)
import Pudu.Frontend.Parser.State
  ( Parser
  , budgetExhausted
  , isSymbol
  , matchKeyword
  , matchSymbol
  , peekKind
  , peekToken
  , advanceToken
  , expectSymbol
  )
import Pudu.Frontend.Parser.Type (parseTypeSyntax)
import Pudu.Frontend.Syntax.Located (Located (..))
import Pudu.Frontend.Syntax.Tree (Constraint (..), TypeParam (..), TypeSyntax)
import Pudu.Frontend.Token (Keyword (KwWhere), TokenKind (..))
import Pudu.Source (Span, mergeSpans)

{-| Parse `[T, U: Bound + Other]`. Generic parameters are optional everywhere
    they appear, so an absent `[` is not a diagnostic. -}
parseTypeParams :: Parser [Located TypeParam]
parseTypeParams = do
  opening <- matchSymbol "["
  case opening of
    Nothing -> pure []
    Just _ -> do
      params <- parseParamList []
      _ <- expectSymbol "]" "to close the generic parameters"
      pure params

parseParamList :: [Located TypeParam] -> Parser [Located TypeParam]
parseParamList reversed = do
  kind <- peekKind
  exhausted <- budgetExhausted
  if isSymbol "]" kind || kind == EndOfFile || exhausted
    then pure (reverse reversed)
    else do
      before <- peekToken
      param <- parseTypeParam
      after <- peekToken
      if before == after
        then pure (reverse reversed)
        else do
          comma <- matchSymbol ","
          case comma of
            Nothing -> pure (reverse (param : reversed))
            Just _ -> parseParamList (param : reversed)

parseTypeParam :: Parser (Located TypeParam)
parseTypeParam = do
  name <- expectUpperIdentifier "for the generic parameter"
  arity <- parseArity
  bounds <- parseBounds
  pure
    ( Located (spanThrough (locatedSpan name) (map locatedSpan bounds))
        TypeParam
          { typeParamName = name
          , typeParamArity = arity
          , typeParamBounds = bounds
          }
    )

{-| A parameter that stands for a constructor says how many arguments it takes,
    by writing that many holes: `F[_]` takes one and `F[_, _]` takes two.

    Holes rather than names, because the arguments have no identity here — the
    parameter is the subject and its arguments are supplied wherever it is
    applied. Naming them would suggest they could be referred to. -}
parseArity :: Parser Int
parseArity = do
  opening <- matchSymbol "["
  case opening of
    Nothing -> pure 0
    Just _ -> countHoles 0

countHoles :: Int -> Parser Int
countHoles seen = do
  taken <- matchHole
  if not taken
    then do
      _ <- expectSymbol "]" "to close the parameter's arguments"
      pure seen
    else do
      next <- matchSymbol ","
      case next of
        Just _ -> countHoles (seen + 1)
        Nothing -> do
          _ <- expectSymbol "]" "to close the parameter's arguments"
          pure (seen + 1)

{-| A hole is the identifier `_`, which the lexer produces as an ordinary name
    and every other phase treats as a discard. -}
matchHole :: Parser Bool
matchHole = do
  kind <- peekKind
  case kind of
    Identifier name | name == "_" -> do
      _ <- advanceToken
      pure True
    _ -> pure False

{-| Bounds are nominal trait references joined by `+`; their meaning is a
    semantic rule, so parsing preserves the spelling only. -}
parseBounds :: Parser [Located TypeSyntax]
parseBounds = do
  colon <- matchSymbol ":"
  case colon of
    Nothing -> pure []
    Just _ -> do
      first <- parseTypeSyntax
      parseBoundTail [first]

parseBoundTail :: [Located TypeSyntax] -> Parser [Located TypeSyntax]
parseBoundTail reversed = do
  plus <- matchSymbol "+"
  case plus of
    Nothing -> pure (reverse reversed)
    Just _ -> do
      before <- peekToken
      next <- parseTypeSyntax
      after <- peekToken
      if before == after
        then pure (reverse reversed)
        else parseBoundTail (next : reversed)

{-| Parse `where T: Bound, U: Other`. The clause ends at the first token that
    cannot continue a constraint list, which is the construct's body. -}
parseWhereClause :: Parser [Located Constraint]
parseWhereClause = do
  keyword <- matchKeyword KwWhere
  case keyword of
    Nothing -> pure []
    Just _ -> parseConstraints []

parseConstraints :: [Located Constraint] -> Parser [Located Constraint]
parseConstraints reversed = do
  before <- peekToken
  subject <- expectUpperIdentifier "for the constraint subject"
  _ <- expectSymbol ":" "before the constraint bounds"
  first <- parseTypeSyntax
  bounds <- parseBoundTail [first]
  after <- peekToken
  let constraint =
        Located (spanThrough (locatedSpan subject) (map locatedSpan bounds))
          Constraint{constraintSubject = subject, constraintBounds = bounds}
      collected = constraint : reversed
  if before == after
    then pure (reverse collected)
    else do
      comma <- matchSymbol ","
      exhausted <- budgetExhausted
      case comma of
        Nothing -> pure (reverse collected)
        Just _ | exhausted -> pure (reverse collected)
        Just _ -> parseConstraints collected

spanThrough :: Span -> [Span] -> Span
spanThrough = foldl (\left right -> maybe left id (mergeSpans left right))
