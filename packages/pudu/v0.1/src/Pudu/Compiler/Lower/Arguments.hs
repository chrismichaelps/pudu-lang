{-| @Compiler.Lower.Arguments — slot selection after operand evaluation. -}
module Pudu.Compiler.Lower.Arguments
  ( ArgumentBlame (..), methodArgumentBlame, argumentFailure, argumentFailureWith
  , ArgumentSlot (..), positionSlot, collectArguments, callWithRuntimeArguments, stopped, stops
  , exactPosition, clampedPosition, wrappedPosition, integerComparison
  ) where

import Data.List (mapAccumL)
import Data.Text (Text)
import qualified Data.Text as Text
import Pudu.Compiler.Lower.Dynamic (mapRuntimeChoice)
import Pudu.Compiler.Lower.State (LowerState (..), bindLocal, intType, refused)
import Pudu.Core
import Pudu.Core.Closure (textMethodPrefix)
import Pudu.Frontend.Syntax (Expression, Located)
import Pudu.IntegerLiteral (IntegerKind (..), integerKindBounds)
import Pudu.Source (Span)

type Lowered = (LowerState, Maybe (CoreExpression, CoreType))

data ArgumentBlame = AtInvocation | AtCaller

{-| Integer slots retain the selected kind until the operation applies its bounds. -}
data ArgumentSlot = ExactSlot !CoreType | IntegerSlot | AnySlot | ShapedSlot !(CoreType -> Bool)

positionSlot :: CoreType -> ArgumentSlot
positionSlot kind
  | kind == intType = IntegerSlot
  | otherwise = ExactSlot kind

methodArgumentBlame :: LowerState -> ArgumentBlame
methodArgumentBlame state
  | any (`Text.isPrefixOf` lowerCurrentKey state) [textMethodPrefix, "$method:", "$trait-method:"] = AtCaller
  | otherwise = AtInvocation

argumentFailure :: ArgumentBlame -> Span -> Text -> Text -> CoreExpression
argumentFailure blame at code message =
  argumentFailureWith blame at code Nothing (CoreExpression at CoreTextType (CoreTextLiteral message))

argumentFailureWith :: ArgumentBlame -> Span -> Text -> Maybe Text -> CoreExpression -> CoreExpression
argumentFailureWith blame at code help message = CoreExpression at CoreNeverType $ case blame of
  AtInvocation -> CoreFailText code help message Nothing
  AtCaller -> CoreFailCaller code help message

collectArguments :: (LowerState -> Located Expression -> Lowered) -> LowerState -> [Located Expression]
  -> (LowerState, Maybe [CoreExpression])
collectArguments lower = collect []
 where
  collect done current [] = (current, Just (reverse done))
  collect done current (argument : remaining) = case lower current argument of
    (after, Nothing) -> refused after
    (after, Just (value, CoreNeverType)) -> (after, Just (reverse (value : done)))
    (after, Just (value, _)) -> collect (value : done) after remaining

callWithRuntimeArguments :: Span -> CoreExpression -> [ArgumentSlot]
  -> (LowerState -> [CoreExpression] -> Lowered)
  -> LowerState -> [CoreExpression] -> Lowered
callWithRuntimeArguments at failure expected invoke state inputs
  | any stops inputs = (state, Just (stopped at inputs, CoreNeverType))
  | length inputs == length expected, and (zipWith direct expected inputs) = invoke state inputs
  | otherwise =
      let (bound, locals) = mapAccumL hold state inputs
          declarations = zipWith declare locals inputs
       in case select bound [] expected (map read' locals) of
            (ready, Just (answer, result)) ->
              (ready, Just (CoreExpression at result (CoreBlockValue (CoreBlock declarations (Just answer))), result))
            (ready, Nothing) -> refused ready
 where
  direct IntegerSlot value = coreExpressionType value == intType
  direct slot value = accepts slot (coreExpressionType value)
  hold current value = bindLocal current "" (coreExpressionType value)
  read' local = CoreExpression at (coreLocalType local) (CoreReadLocal local)
  declare local value = CoreStatement (coreExpressionSpan value) (CoreDeclare local value)
  select current done [] [] = invoke current (reverse done)
  select current done requested@(slot : rest) (given : remaining)
    | accepts slot (coreExpressionType given) = select current (given : done) rest remaining
    | Just selected <- mapRuntimeChoice current at CoreNeverType given
        (\ready value -> fmap (fmap fst) (select ready done requested (value : remaining))) = selected
  select current _ _ _ = (current, Just (failure, CoreNeverType))

accepts :: ArgumentSlot -> CoreType -> Bool
accepts (ExactSlot expected) actual = expected == actual
accepts IntegerSlot (CoreIntegerType _) = True
accepts IntegerSlot _ = False
accepts AnySlot _ = True
accepts (ShapedSlot predicate) actual = predicate actual

exactPosition :: Span -> CoreExpression -> (CoreExpression, CoreExpression)
exactPosition at value
  | coreExpressionType value == intType = (CoreExpression at CoreBoolType (CoreBoolLiteral True), value)
  | otherwise =
      (CoreExpression at CoreBoolType (CoreIntegerFits PlatformSigned value),
       CoreExpression at intType (CoreIntegerConvert PlatformSigned value))

clampedPosition :: Span -> CoreExpression -> CoreExpression
clampedPosition at value
  | coreExpressionType value == intType = value
  | CoreIntegerType kind <- coreExpressionType value
  , Just (low, high) <- integerKindBounds PlatformSigned =
      let (fits, converted) = exactPosition at value
          negative = integerComparison at CoreLess value (CoreExpression at (CoreIntegerType kind) (CoreIntegerLiteral kind 0))
          limited = choose negative (number low) (number high)
       in choose fits converted limited
  | otherwise = value
 where
  choose condition yes no = CoreExpression at intType (CoreIfValue condition (CoreBlock [] (Just yes)) no)
  number = CoreExpression at intType . CoreIntegerLiteral PlatformSigned

wrappedPosition :: Span -> CoreExpression -> CoreExpression
wrappedPosition at value
  | coreExpressionType value == intType = value
  | otherwise = CoreExpression at intType (CoreBinary CoreWrapAdd narrowed zero)
 where
  narrowed = CoreExpression at intType (CoreIntegerConvert PlatformSigned value)
  zero = CoreExpression at intType (CoreIntegerLiteral PlatformSigned 0)

integerComparison :: Span -> CoreBinaryOperator -> CoreExpression -> CoreExpression -> CoreExpression
integerComparison at operator left right = CoreExpression at CoreBoolType $
  if coreExpressionType left == coreExpressionType right
    then CoreBinary operator left right
    else CoreBinary operator (asBig left) (asBig right)
 where
  asBig value
    | coreExpressionType value == CoreIntegerType BigIntKind = value
    | otherwise = CoreExpression at (CoreIntegerType BigIntKind) (CoreIntegerConvert BigIntKind value)

stops :: CoreExpression -> Bool
stops core = coreExpressionType core == CoreNeverType

stopped :: Span -> [CoreExpression] -> CoreExpression
stopped at cores = CoreExpression at CoreNeverType (CoreBlockValue (CoreBlock
  [CoreStatement (coreExpressionSpan core) (CoreEvaluate core) | core <- cores] Nothing))
