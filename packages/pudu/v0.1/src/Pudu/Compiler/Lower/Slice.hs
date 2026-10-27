{-| @Pudu.Compiler.Lower.Slice — `items[a..b]` on an array or Str, with the
    range written in the brackets. The checks are `rangeBounds`' own: both
    ends inside the value, then the end not before the start, and only then
    the slice, which no longer has anything to clamp. -}
module Pudu.Compiler.Lower.Slice (lowerRangeIndex) where

import Pudu.Compiler.Lower.Array (collect, stopped, stops)
import Pudu.Compiler.Lower.State (LowerContext (..), LowerState (..), bindLocal, halt, intType, refused)
import Pudu.Compiler.Lower.Types (typeForSpan)
import Pudu.Core
import Pudu.Frontend.Syntax (Expression (..), Located (..))
import Pudu.IntegerLiteral (IntegerKind (..))

type LowerExpression = LowerState -> Located Expression -> (LowerState, Maybe (CoreExpression, CoreType))
type Lowered = (LowerState, Maybe (CoreExpression, CoreType))

{-| The receiver runs first, then the start, then the end, the order
    `readIndex` sees them in. A failure reports at the range. -}
lowerRangeIndex :: LowerExpression -> LowerState -> Located Expression -> Located Expression -> Maybe Lowered
lowerRangeIndex lower state receiver key@(Located at keyShape) = case (receiverKind, keyShape) of
  (Just kind, RangeExpression lower' inclusive upper')
    | sliceable kind -> Just $ case collect lower state (receiver : foldMap pure lower' <> foldMap pure upper') of
        (after, Nothing) -> refused after
        (after, Just cores)
          | any stops cores -> (after, Just (stopped at cores, CoreNeverType))
          | all ((== intType) . coreExpressionType) (drop 1 cores) -> case cores of
              container : ends ->
                let (low, high) = case (lower', upper', ends) of
                      (Just _, Just _, [l, h]) -> (Just l, Just h)
                      (Just _, Nothing, [l]) -> (Just l, Nothing)
                      (Nothing, Just _, [h]) -> (Nothing, Just h)
                      _ -> (Nothing, Nothing)
                 in sliced after kind container low inclusive high
              [] -> refused after
          | otherwise -> halt (locatedSpan key) "a slice range whose ends are not Int" after
  _ -> Nothing
 where
  receiverKind = typeForSpan (contextTypes (lowerContext state)) (locatedSpan receiver)
  sliceable kind = case kind of
    CoreArrayType _ -> True
    CoreTextType -> True
    _ -> False

  sliced current kind container low inclusive high =
    let (s1, held) = hidden current kind
        (s2, size) = hidden s1 intType
        (s3, start) = hidden s2 intType
        (s4, end) = hidden s3 intType
        (s5, stop) = hidden s4 intType
        lengthOf = case kind of
          CoreTextType -> expression intType (CoreTextMethod TextLength (reading held) [])
          _ -> expression intType (CoreArrayMethod ArrayLengthOf (reading held) [])
        startOutside = [compare' CoreLess (reading start) zero, compare' CoreGreater (reading start) (reading size)]
        endOutside = case high of
          Nothing -> []
          Just _ -> [compare' CoreLess (reading end) zero, compare' (if inclusive then CoreGreaterOrEqual else CoreGreater) (reading end) (reading size)]
        outside = foldr1 (\a b -> expression CoreBoolType (CoreBinary CoreOr a b)) (startOutside <> endOutside)
        stopValue = case high of
          Nothing -> reading size
          Just _ | inclusive -> expression intType (CoreBinary CoreAdd (reading end) one)
                 | otherwise -> reading end
        lengthHelp = foldl1 (\a b -> expression CoreTextType (CoreBinary CoreAdd a b))
          [ text "the range must lie within the value; it has ", expression CoreTextType (CoreDisplay (reading size)), text " elements" ]
        sliceOf = case kind of
          CoreTextType -> expression kind (CoreTextMethod TextSlice (reading held) [reading start, reading stop])
          _ -> expression kind (CoreArrayMethod ArraySliceOf (reading held) [reading start, reading stop])
        statements =
          [ declare held container
          , declare start (maybe zero id low)
          , declare end (maybe zero id high)
          , declare size lengthOf
          , when' outside (fail' "slice range out of bounds" Nothing (Just lengthHelp))
          , declare stop stopValue
          , when' (compare' CoreLess (reading stop) (reading start))
              (fail' "slice range ends before it starts" (Just "write the lower bound first") Nothing) ]
     in (s5, Just (expression kind (CoreBlockValue (CoreBlock statements (Just sliceOf))), kind))

  hidden current kind = bindLocal current "" kind
  expression kind shape = CoreExpression at kind shape
  statement shape = CoreStatement at shape
  reading local = expression (coreLocalType local) (CoreReadLocal local)
  declare local value = statement (CoreDeclare local value)
  number value = expression intType (CoreIntegerLiteral PlatformSigned value)
  zero = number 0
  one = number 1
  text value = expression CoreTextType (CoreTextLiteral value)
  compare' operator a b = expression CoreBoolType (CoreBinary operator a b)
  when' condition failure = statement (CoreIf condition (CoreBlock [statement (CoreEvaluate failure)] Nothing) Nothing)
  fail' message help computed = expression CoreNeverType (CoreFailText "E7004" help (text message) computed)
