{-| @Pudu.Compiler.Lower.Range — ranges as values: built from the ends
    written, and their methods, as `Eval.Range` answers them. Arguments run
    before the receiver. -}
module Pudu.Compiler.Lower.Range (lowerRangeValue, lowerRangeMethod) where

import Data.Text (Text)
import Pudu.Compiler.Lower.Array (collect, lowerArrayLoop, stopped, stops)
import Pudu.Compiler.Lower.State (LowerContext (..), LowerState (..), bindLocal, halt, intType, refused)
import Pudu.Compiler.Lower.Types (typeForSpan)
import Pudu.Core
import Pudu.Frontend.Syntax (Expression, Located (..))
import Pudu.Source (Span)

type LowerExpression = LowerState -> Located Expression -> (LowerState, Maybe (CoreExpression, CoreType))
type Lowered = (LowerState, Maybe (CoreExpression, CoreType))

{-| `a..b` and its other shapes as a value: the start runs, then the end. -}
lowerRangeValue :: LowerExpression -> LowerState -> Span -> Maybe (Located Expression) -> Bool -> Maybe (Located Expression) -> Lowered
lowerRangeValue lower state at low inclusive high = case collect lower state (foldMap pure low <> foldMap pure high) of
  (after, Nothing) -> refused after
  (after, Just cores)
    | any stops cores -> (after, Just (stopped at cores, CoreNeverType))
    | any ((/= intType) . coreExpressionType) cores -> halt at "a range whose ends are not Int" after
    | otherwise ->
        let (start, end) = case (low, high, cores) of
              (Just _, Just _, [l, h]) -> (Just l, Just h)
              (Just _, Nothing, [l]) -> (Just l, Nothing)
              (Nothing, Just _, [h]) -> (Nothing, Just h)
              _ -> (Nothing, Nothing)
         in (after, Just (CoreExpression at CoreRangeType (CoreRangeValue start inclusive end), CoreRangeType))

{-| A method of a range value; Nothing when the receiver is not one. -}
lowerRangeMethod :: LowerExpression -> LowerState -> Span -> Located Expression -> Text -> [Located Expression] -> Maybe Lowered
lowerRangeMethod lower state at receiver member arguments = case typeForSpan types (locatedSpan receiver) of
  Just CoreRangeType -> Just $ case member of
    _ | member `elem` ["map", "filter", "reduce"] ->
          lowerArrayLoop lower state at receiver member arguments numbers
            (\core -> CoreExpression at numbers (CoreRangeMethod (RangeValuesFor member) core []))
    "start" -> optional RangeHasStart RangeStartOf
    "end" -> optional RangeHasEnd RangeEndOf
    _ -> case lookup member direct of
      Just (name, parameters, result) -> plain name parameters result
      Nothing -> halt at ("the Range method '" <> member <> "'") state
  _ -> Nothing
 where
  types = contextTypes (lowerContext state)
  numbers = CoreArrayType intType
  direct =
    [ ("length", (RangeLengthOf, [], intType))
    , ("isEmpty", (RangeIsEmptyOf, [], CoreBoolType))
    , ("contains", (RangeContainsValue, [intType], CoreBoolType))
    , ("isInclusive", (RangeIsInclusiveOf, [], CoreBoolType))
    , ("isBounded", (RangeIsBoundedOf, [], CoreBoolType))
    , ("toArray", (RangeValuesFor "toArray", [], numbers))
    , ("reverse", (RangeReversedOf, [], numbers))
    , ("step", (RangeStepBy, [intType], numbers))
    , ("sum", (RangeSumOf, [], intType)) ]
  operands = collect lower state (arguments <> [receiver])
  plain name parameters result = case operands of
    (after, Nothing) -> refused after
    (after, Just cores)
      | any stops cores -> (after, Just (stopped at cores, CoreNeverType))
      | map coreExpressionType (init cores) /= parameters -> halt at ("a call to " <> member <> " with these arguments") after
      | otherwise -> (after, Just (CoreExpression at result (CoreRangeMethod name (last cores) (init cores)), result))
  -- start and end: Some of the end when the range has it, None otherwise.
  optional has value = case (typeForSpan types at, operands) of
    (_, (after, Nothing)) -> refused after
    (_, (after, Just cores)) | any stops cores -> (after, Just (stopped at cores, CoreNeverType))
    (Just option@(CoreSumType _ _), (after, Just [core])) ->
      let (withRange, range) = bindLocal after "" CoreRangeType
          read' = CoreExpression at CoreRangeType (CoreReadLocal range)
          some = CoreExpression at option (CoreConstruct "Some" [("0", CoreExpression at intType (CoreRangeMethod value read' []))])
          none = CoreExpression at option (CoreConstruct "None" [])
          choice = CoreExpression at option (CoreIfValue (CoreExpression at CoreBoolType (CoreRangeMethod has read' [])) (CoreBlock [] (Just some)) none)
       in (withRange, Just (CoreExpression at option (CoreBlockValue (CoreBlock [CoreStatement at (CoreDeclare range core)] (Just choice))), option))
    (_, (after, _)) -> halt at ("a call to " <> member <> " with these arguments") after
