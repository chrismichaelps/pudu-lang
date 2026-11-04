{-| @Pudu.Compiler.Lower.Bytes — `bytesOf` and the built-in methods of a byte
    sequence, as `Eval.Bytes` answers them. Arguments run before the
    receiver. -}
module Pudu.Compiler.Lower.Bytes (lowerBytesOf, lowerBytesMethod, bytesFromArray) where

import Data.Text (Text)
import Pudu.Compiler.Lower.Array (collect, stopped, stops)
import Pudu.Compiler.Lower.State (LowerContext (..), LowerState (..), bindLocal, halt, intType, refused)
import Pudu.Compiler.Lower.Types (typeForSpan)
import Pudu.Core
import Pudu.Frontend.Syntax (Expression, Located (..))
import Pudu.IntegerLiteral (IntegerKind (..))
import Pudu.Source (Span)

type LowerExpression = LowerState -> Located Expression -> (LowerState, Maybe (CoreExpression, CoreType))
type Lowered = (LowerState, Maybe (CoreExpression, CoreType))

byteType :: CoreType
byteType = CoreIntegerType (UnsignedKind 8)

{-| `bytesOf(array)`: one byte per item; a UInt8 always fits. -}
lowerBytesOf :: LowerExpression -> LowerState -> Span -> [Located Expression] -> Lowered
lowerBytesOf lower state at arguments = case collect lower state arguments of
  (after, Nothing) -> refused after
  (after, Just cores)
    | any stops cores -> (after, Just (stopped at cores, CoreNeverType))
    | [array] <- cores, coreExpressionType array == CoreArrayType byteType ->
        (after, Just (bytesFromArray at array, CoreBytesType))
    | otherwise -> halt at "this call to bytesOf" after

{-| What `bytesOf` makes of a lowered `Array[UInt8]`. -}
bytesFromArray :: Span -> CoreExpression -> CoreExpression
bytesFromArray at array = CoreExpression at CoreBytesType (CoreBytesMethod BytesOfArray array [])

{-| A method of a byte sequence; Nothing when the receiver is not one. -}
lowerBytesMethod :: LowerExpression -> LowerState -> Span -> Located Expression -> Text -> [Located Expression] -> Maybe Lowered
lowerBytesMethod lower state at receiver member arguments = case typeForSpan types (locatedSpan receiver) of
  Just CoreBytesType -> Just $ case collect lower state (arguments <> [receiver]) of
    (after, Nothing) -> refused after
    (after, Just cores)
      | any stops cores -> (after, Just (stopped at cores, CoreNeverType))
      | otherwise -> case (member, cores) of
          ("isEmpty", [bytes]) -> built after CoreBoolType (CoreBinary CoreEqual (method intType BytesLengthOf bytes []) (number 0))
          ("at", [index, bytes]) | coreExpressionType index == intType -> at' after index bytes
          ("toText", [bytes]) -> asText after bytes
          _ -> case (lookup member direct, reverse cores) of
            (Just (name, parameters, result), bytes : reversed)
              | let operands = reverse reversed
              , map coreExpressionType operands == parameters ->
                  built after result (CoreBytesMethod name bytes operands)
            _ -> halt at ("a call to " <> member <> " on Bytes with these arguments") after
  _ -> Nothing
 where
  types = contextTypes (lowerContext state)
  direct =
    [ ("length", (BytesLengthOf, [], intType))
    , ("slice", (BytesSliceOf, [intType, intType], CoreBytesType))
    , ("take", (BytesTakeOf, [intType], CoreBytesType))
    , ("drop", (BytesDropOf, [intType], CoreBytesType))
    , ("concat", (BytesConcatWith, [CoreBytesType], CoreBytesType))
    , ("indexOf", (BytesIndexOfValue, [CoreBytesType], intType))
    , ("contains", (BytesContainsValue, [CoreBytesType], CoreBoolType))
    , ("startsWith", (BytesStartsWithValue, [CoreBytesType], CoreBoolType))
    , ("endsWith", (BytesEndsWithValue, [CoreBytesType], CoreBoolType))
    , ("reverse", (BytesReversed, [], CoreBytesType))
    , ("toArray", (BytesToArrayOf, [], CoreArrayType byteType)) ]
  built after kind shape = (after, Just (CoreExpression at kind shape, kind))
  method kind name receiver' operands = CoreExpression at kind (CoreBytesMethod name receiver' operands)
  number value = CoreExpression at intType (CoreIntegerLiteral PlatformSigned value)
  reading local = CoreExpression at (coreLocalType local) (CoreReadLocal local)
  compare' operator a b = CoreExpression at CoreBoolType (CoreBinary operator a b)
  optionAt = typeForSpan types at
  -- at: Some(byte) when 0 <= index < length, None otherwise.
  at' current index bytes = case optionAt of
    Just option@(CoreSumType _ _) ->
      let (withIndex, indexLocal) = bindLocal current "" intType
          (withBytes, bytesLocal) = bindLocal withIndex "" CoreBytesType
          inside = compare' CoreAnd (compare' CoreGreaterOrEqual (reading indexLocal) (number 0))
            (compare' CoreLess (reading indexLocal) (method intType BytesLengthOf (reading bytesLocal) []))
          some = CoreExpression at option (CoreConstruct "Some" [("0", method byteType BytesAtIndex (reading bytesLocal) [reading indexLocal])])
          none = CoreExpression at option (CoreConstruct "None" [])
          choice = CoreExpression at option (CoreIfValue inside (CoreBlock [] (Just some)) none)
       in (withBytes, Just (CoreExpression at option (CoreBlockValue (CoreBlock
            [CoreStatement at (CoreDeclare indexLocal index), CoreStatement at (CoreDeclare bytesLocal bytes)] (Just choice))), option))
    _ -> halt at "an Option result of at without a native form" current
  -- toText: Some of the same storage when it is valid UTF-8, None otherwise.
  asText current bytes = case optionAt of
    Just option@(CoreSumType _ _) ->
      let (withBytes, bytesLocal) = bindLocal current "" CoreBytesType
          some = CoreExpression at option (CoreConstruct "Some" [("0", method CoreTextType BytesAsText (reading bytesLocal) [])])
          none = CoreExpression at option (CoreConstruct "None" [])
          choice = CoreExpression at option (CoreIfValue (method CoreBoolType BytesIsText (reading bytesLocal) []) (CoreBlock [] (Just some)) none)
       in (withBytes, Just (CoreExpression at option (CoreBlockValue (CoreBlock [CoreStatement at (CoreDeclare bytesLocal bytes)] (Just choice))), option))
    _ -> halt at "an Option result of toText without a native form" current
