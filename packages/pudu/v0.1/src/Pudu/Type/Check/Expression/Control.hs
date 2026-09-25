{-| @Type.Check.Expression.Control — control flow, match arms, and lambda typing for expressions. -}
module Pudu.Type.Check.Expression.Control
  ( checkArms
  , lambdaType
  , aroundLoop
  , literalIndex
  ) where

import Data.Text (Text)
import Pudu.Frontend.Syntax.Located (Located (..))
import Pudu.IntegerLiteral (ParsedInteger (..), parseIntegerLiteral)
import qualified Pudu.Frontend.Syntax.Tree as Tree
import Pudu.Frontend.Syntax.Tree
  ( Block (..)
  , Expression (..)
  , Function (..)
  , FunctionBody (..)
  , MatchArm (..)
  , Parameter
  )
import Pudu.Source (Span)
import Pudu.Type.Env
  ( Checker
  , DeclaredTypes (..)
  , bindName
  , enterLoop
  , freshVariable
  , inTypeScope
  , inTypeScopeWith
  , insideClosure
  , integerLiteralCheckpoint
  , leaveLoop
  , validateIntegerLiteralsSince
  , withoutLoops
  )
import Pudu.Type.Check.Pattern (bindPattern)
import Pudu.Type.Check.Place (checkAnswer, checkParameterTypes, noteUnwrittenParameters)
import Pudu.Type.Check.Rule (selfName)
import Pudu.Type.Formation (formOptionalType)
import Pudu.Type.Unify (unify, zonk)
import Pudu.Type.Value
  ( Type (..)
  , boolType
  , monotype
  )

checkArms
  :: (Located Expression -> Checker Type)
  -> DeclaredTypes
  -> [(Text, Int)]
  -> Span
  -> Type
  -> [Located MatchArm]
  -> Checker Type
checkArms checkExpr declared rigid spanValue subjectType arms = case arms of
  [] -> pure ErrorType
  _ -> do
    checkpoint <- integerLiteralCheckpoint
    types <- mapM checkArm arms
    unified <- case types of
      [] -> pure ErrorType
      first : rest -> foldUnify first rest
    validateIntegerLiteralsSince checkpoint
    resolved <- mapM zonk types
    if ErrorType `elem` resolved then pure ErrorType else zonk unified
 where
  checkArm (Located _ arm) = do
    result <- freshVariable
    inTypeScope $ do
      bindPattern declared rigid (armPattern arm) subjectType
      case armGuard arm of
        Nothing -> pure ()
        Just guard -> do
          guardType <- checkExpr guard
          _ <- unify (locatedSpan guard) boolType guardType
          pure ()
      bodyType <- checkExpr (armBody arm)
      _ <- unify (locatedSpan (armBody arm)) result bodyType
      pure ()
    pure result
  foldUnify current rest = case rest of
    [] -> pure current
    next : remaining -> do
      unified <- unify spanValue current next
      foldUnify unified remaining

{-| Type a function literal.

    The literal is checked exactly like a declaration's body — its parameters
    bound, its result unified with what the body produced — and answers with the
    function type a caller sees. -}
lambdaType
  :: (Located Parameter -> Checker Type)
  -> (Located Block -> Checker Type)
  -> (Located Expression -> Checker Type)
  -> DeclaredTypes
  -> [(Text, Int)]
  -> Function
  -> Checker Type
lambdaType checkParam checkBlock checkExpr declared rigid value =
  withoutLoops $ insideClosure $ inTypeScopeWith $ do
    inputs <- mapM checkParam (functionParameters value)
    checkParameterTypes value
    noteUnwrittenParameters value inputs
    result <- formOptionalType declared rigid (functionReturn value)
    let signature = FunctionTypeValue (functionAsync value) inputs result
    bindName selfName (monotype signature)
    case functionBody value of
      Nothing -> pure ()
      Just (Located bodySpan body) -> do
        actual <- case body of
          BlockBody block -> checkBlock block
          ExpressionBody expression -> checkExpr expression
        _ <- unify bodySpan result actual
        pure ()
    checkAnswer value result
    zonk signature

{-| Check a loop body with that loop on the stack, reporting whether any
    `break` left it. -}
aroundLoop :: Maybe (Located Text) -> Type -> Bool -> Checker a -> Checker Bool
aroundLoop label result carries action = do
  enterLoop (fmap locatedValue label) result carries
  _ <- action
  leaveLoop

{-| Extract a constant integer index from an expression, if it is one. -}
literalIndex :: Located Expression -> Maybe Integer
literalIndex (Located _ expression) = case expression of
  LiteralExpression (Tree.IntegerValue text) ->
    parsedIntegerValue <$> parseIntegerLiteral text
  _ -> Nothing
