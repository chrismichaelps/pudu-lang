{-| @Pudu.Compiler.Lower.Convert — `convertInteger[T](value)`. The value runs
    into a local, then a fit test picks `Some` of the converted value or
    `None`, as `callConvertInteger` answers. -}
module Pudu.Compiler.Lower.Convert (lowerConvertInteger, lowerCharFromCode, charFromCodeCore) where

import Pudu.Compiler.Lower.Control (expressionIsPrintValued)
import Pudu.Compiler.Lower.State (LowerContext (..), LowerState (..), bindLocal, halt, intType, refused)
import Pudu.IntegerLiteral (IntegerKind (..))
import Pudu.Compiler.Lower.Types (typeForSpan)
import Pudu.Core
import Pudu.Frontend.Syntax (Expression, Located (..))
import Pudu.Source (Span)

type LowerExpression = LowerState -> Located Expression -> (LowerState, Maybe (CoreExpression, CoreType))

{-| The target is read from the call's checked `Option[T]`. -}
lowerConvertInteger :: LowerExpression -> LowerState -> Span -> [Located Expression] -> (LowerState, Maybe (CoreExpression, CoreType))
lowerConvertInteger lower state at arguments = case (typeForSpan (contextTypes (lowerContext state)) at, arguments) of
  (Just option@(CoreSumType _ [target@(CoreIntegerType kind)]), [argument]) -> case lower state argument of
    (after, Nothing) -> refused after
    (after, Just (core, CoreNeverType)) -> (after, Just (core, CoreNeverType))
    (after, Just (core, CoreIntegerType _))
      | expressionIsPrintValued core -> halt (locatedSpan argument) "a Result[(), Str] call argument" after
      | otherwise ->
          let (withHeld, held) = bindLocal after "" (coreExpressionType core)
              expression shape kind' = CoreExpression at kind' shape
              value = expression (CoreReadLocal held) (coreExpressionType core)
              some = expression (CoreConstruct "Some" [("0", expression (CoreIntegerConvert kind value) target)]) option
              none = expression (CoreConstruct "None" []) option
              choice = expression (CoreIfValue (expression (CoreIntegerFits kind value) CoreBoolType) (CoreBlock [] (Just some)) none) option
           in (withHeld, Just (expression (CoreBlockValue (CoreBlock [CoreStatement at (CoreDeclare held core)] (Just choice))) option, option))
    (after, Just (_, kind')) -> halt (locatedSpan argument) ("convertInteger from a " <> coreTypeName kind') after
  _ -> halt at "this convertInteger call" state

{-| `charFromCode(code)`: Some of the Char when the code is a Unicode scalar
    value (0 through 0x10FFFF, surrogates excluded), None otherwise. -}
lowerCharFromCode :: LowerExpression -> LowerState -> Span -> [Located Expression] -> (LowerState, Maybe (CoreExpression, CoreType))
lowerCharFromCode lower state at arguments = case (typeForSpan (contextTypes (lowerContext state)) at, arguments) of
  (Just option@(CoreSumType _ _), [argument]) -> case lower state argument of
    (after, Nothing) -> refused after
    (after, Just (core, CoreNeverType)) -> (after, Just (core, CoreNeverType))
    (after, Just (core, kind'))
      | kind' /= intType || expressionIsPrintValued core -> halt (locatedSpan argument) "this charFromCode argument" after
      | otherwise -> charFromCodeCore after at option core
  _ -> halt at "this charFromCode call" state

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
