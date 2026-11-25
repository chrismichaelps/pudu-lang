{-| @Pudu.Compiler.Lower.Convert — `convertInteger[T](value)`. The value runs
    into a local, then a fit test picks `Some` of the converted value or
    `None`, as `callConvertInteger` answers. -}
module Pudu.Compiler.Lower.Convert (lowerConvertInteger, lowerFittingUnwrap, lowerCharFromCode, charFromCodeArguments) where

import Pudu.Compiler.Lower.Arguments
  ( ArgumentBlame (..), ArgumentSlot (IntegerSlot), argumentFailure, argumentFailureWith
  , callWithRuntimeArguments, clampedPosition, collectArguments
  )
import Pudu.Compiler.Lower.Dynamic (mapRuntimeChoice)
import Data.List.NonEmpty (NonEmpty (..))
import Pudu.Compiler.Lower.State (LowerContext (..), LowerState (..), bindLocal, halt, intType, lookupLocal, refused, resolveFunction)
import Pudu.IntegerLiteral (IntegerKind (..), integerKindBounds)
import Pudu.Compiler.Lower.Types (typeForSpan)
import Pudu.Core
import Pudu.Frontend.Syntax (Expression (..), Located (..))
import Pudu.Source (Span)

type LowerExpression = LowerState -> Located Expression -> (LowerState, Maybe (CoreExpression, CoreType))

{-| The target is read from the call's checked `Option[T]`. -}
lowerConvertInteger :: LowerExpression -> LowerState -> Span -> [Located Expression] -> (LowerState, Maybe (CoreExpression, CoreType))
lowerConvertInteger lower state at arguments = case (typeForSpan (contextTypes (lowerContext state)) at, arguments) of
  (Just option@(CoreSumType _ [target@(CoreIntegerType kind)]), [argument]) -> case lower state argument of
    (after, Nothing) -> refused after
    (after, Just (core, CoreNeverType)) -> (after, Just (core, CoreNeverType))
    (after, Just (core, _)) -> select option target kind after core
  _ -> halt at "this convertInteger call" state
 where
  expression = CoreExpression at
  select option target kind current core
    | Just chosen <- mapRuntimeChoice current at option core
        (\ready held -> fmap (fmap fst) (select option target kind ready held)) = chosen
    | CoreIntegerType source <- coreExpressionType core, fitsWithin source kind =
        (current, Just (expression option (CoreConstruct "Some" [("0", expression target (CoreIntegerConvert kind core))]), option))
    | CoreIntegerType _ <- coreExpressionType core =
        let (withHeld, held) = bindLocal current "" (coreExpressionType core)
            value = expression (coreExpressionType core) (CoreReadLocal held)
            some = expression option (CoreConstruct "Some" [("0", expression target (CoreIntegerConvert kind value))])
            none = expression option (CoreConstruct "None" [])
            choice = expression option (CoreIfValue (expression CoreBoolType (CoreIntegerFits kind value))
              (CoreBlock [] (Just some)) none)
         in (withHeld, Just (expression option (CoreBlockValue (CoreBlock [CoreStatement at (CoreDeclare held core)] (Just choice))), option))
    | otherwise =
        let message = expression CoreTextType (CoreBinary CoreAdd
              (expression CoreTextType (CoreTextLiteral "convertInteger moves between integers, not from a "))
              (expression CoreTextType (CoreRuntimeKind core)))
            failed = argumentFailureWith AtInvocation at "E7012" Nothing message
         in (current, Just (failed, CoreNeverType))

{-| Whether every value of the first kind is a value of the second. An exact
    integer is held without a bound, so it is never known to fit. -}
fitsWithin :: IntegerKind -> IntegerKind -> Bool
fitsWithin ExactIntKind _ = False
fitsWithin source target = case (integerKindBounds source, integerKindBounds target) of
  (_, Nothing) -> True
  (Nothing, Just _) -> False
  (Just (low, high), Just (floor', ceiling')) -> low >= floor' && high <= ceiling'

{-| `Option.unwrapOr(convertInteger[T](value), fallback)` where every value
    of the operand's kind is a `T`: the operand, then the fallback, run in
    order, and the answer is the widened operand, with no option between. -}
lowerFittingUnwrap :: LowerExpression -> LowerState -> Span -> [Located Expression] -> Maybe (LowerState, Maybe (CoreExpression, CoreType))
lowerFittingUnwrap lower state at arguments = case arguments of
  [Located _ (CallExpression (Located _ (TypeApplication (Located _ (NameExpression ("convertInteger" :| []))) _)) [operand@(Located operandAt _)]), fallback]
    | Nothing <- lookupLocal state "convertInteger"
    , Nothing <- resolveFunction state ["convertInteger"]
    , Just target@(CoreIntegerType kind) <- typeForSpan types at
    , Just (CoreIntegerType source) <- typeForSpan types operandAt
    , fitsWithin source kind -> Just $ case lower state operand of
        (after, Nothing) -> refused after
        (after, Just (core, CoreNeverType)) -> (after, Just (core, CoreNeverType))
        (after, Just (core, kind')) -> case lower after fallback of
          (afterFallback, Nothing) -> refused afterFallback
          (afterFallback, Just (fallbackCore, _)) ->
            let (withHeld, held) = bindLocal afterFallback "" kind'
                value = CoreExpression at kind' (CoreReadLocal held)
                widened = CoreExpression at target (CoreIntegerConvert kind value)
             in (withHeld, Just (CoreExpression at target (CoreBlockValue (CoreBlock
                  [CoreStatement at (CoreDeclare held core), CoreStatement at (CoreEvaluate fallbackCore)] (Just widened))), target))
  _ -> Nothing
 where
  types = contextTypes (lowerContext state)

{-| The scalar range check is shared by direct and stored calls. -}
lowerCharFromCode :: LowerExpression -> LowerState -> Span -> [Located Expression] -> (LowerState, Maybe (CoreExpression, CoreType))
lowerCharFromCode lower state at arguments = case typeForSpan (contextTypes (lowerContext state)) at of
  Just option@(CoreSumType _ _) -> case collectArguments lower state arguments of
    (after, Nothing) -> refused after
    (after, Just operands) -> charFromCodeArguments AtInvocation at option after operands
  _ -> halt at "this charFromCode call" state

charFromCodeArguments :: ArgumentBlame -> Span -> CoreType -> LowerState -> [CoreExpression]
  -> (LowerState, Maybe (CoreExpression, CoreType))
charFromCodeArguments blame at option = callWithRuntimeArguments at failure [IntegerSlot] apply
 where
  failure = argumentFailure blame at "E7012" "charFromCode expects one integer"
  apply current [value] = charFromCodeCore current at option (clampedPosition at value)
  apply current _ = refused current

{-| The body of `charFromCode` for an Int that has already been lowered. -}
charFromCodeCore :: LowerState -> Span -> CoreType -> CoreExpression -> (LowerState, Maybe (CoreExpression, CoreType))
charFromCodeCore state at option core =
  let (withHeld, held) = bindLocal state "" intType
      expression shape kind = CoreExpression at kind shape
      code = expression (CoreReadLocal held) intType
      number value = expression (CoreIntegerLiteral PlatformSigned value) intType
      test operator bound = expression (CoreBinary operator code (number bound)) CoreBoolType
      both a b = expression (CoreBinary CoreAnd a b) CoreBoolType
      scalar = both (both (test CoreGreaterOrEqual 0) (test CoreLessOrEqual 0x10FFFF))
        (expression (CoreNot (both (test CoreGreaterOrEqual 0xD800) (test CoreLessOrEqual 0xDFFF))) CoreBoolType)
      some = expression (CoreConstruct "Some" [("0", expression (CoreCharOfCode code) CoreCharType)]) option
      none = expression (CoreConstruct "None" []) option
      choice = expression (CoreIfValue scalar (CoreBlock [] (Just some)) none) option
   in (withHeld, Just (expression (CoreBlockValue (CoreBlock [CoreStatement at (CoreDeclare held core)] (Just choice))) option, option))
