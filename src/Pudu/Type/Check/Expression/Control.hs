{-| @Type.Check.Expression.Control — control flow, match arms, and lambda typing for expressions. -}
module Pudu.Type.Check.Expression.Control
  ( checkArms
  , lambdaType
  , checkCapturedAssignment
  , aroundLoop
  , literalIndex
  ) where

import qualified Data.List.NonEmpty as NonEmpty
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
  , capturedFromOutside
  , enterLoop
  , freshVariable
  , inTypeScope
  , inTypeScopeWith
  , insideClosure
  , integerLiteralCheckpoint
  , leaveLoop
  , report
  , validateIntegerLiteralsSince
  , withoutLoops
  )
import Pudu.Type.Check.Pattern (bindPattern)
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
    zonk signature

{-| Refuse an assignment to a name the closure only captured. -}
checkCapturedAssignment :: Text -> Located Expression -> Checker ()
checkCapturedAssignment operator (Located spanValue expression)
  | operator /= "=" = pure ()
  | otherwise = case expression of
      NameExpression names | [name] <- NonEmpty.toList names -> do
        captured <- capturedFromOutside name
        if captured
          then
            report "E3076" spanValue
              ("assignment to " <> name <> " does not leave this closure")
              ( Just
                  ( "a closure holds its own copy of what it captured; return the "
                      <> "value instead, or carry it in what the closure answers"
                  )
              )
          else pure ()
      _ -> pure ()

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
