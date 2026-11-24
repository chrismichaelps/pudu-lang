{-| @Pudu.Compiler.Lower.Bytes — `bytesOf` and the built-in methods of a byte
    sequence. The receiver and arguments retain their source evaluation order. -}
module Pudu.Compiler.Lower.Bytes (lowerBytesOf, lowerBytesOn, bytesOfArguments) where

import Data.Text (Text)
import Pudu.Compiler.Lower.Arguments
  ( ArgumentBlame (..), ArgumentSlot (ExactSlot), argumentFailure, argumentFailureWith, callWithRuntimeArguments
  , clampedPosition, collectArguments, integerComparison, methodArgumentBlame, positionSlot
  )
import Pudu.Compiler.Lower.Array (stopped, stops)
import Pudu.Compiler.Lower.Control (popLoop, pushLoop)
import Pudu.Compiler.Lower.Dynamic (mapRuntimeChoice)
import Pudu.Compiler.Lower.State (LowerState, bindLocal, halt, intType, refused)
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
lowerBytesOf lower state at arguments = case collectArguments lower state arguments of
  (after, Nothing) -> refused after
  (after, Just operands) -> bytesOfArguments AtInvocation at after operands

bytesOfArguments :: ArgumentBlame -> Span -> LowerState -> [CoreExpression] -> Lowered
bytesOfArguments blame at state operands
  | any stops operands = (state, Just (stopped at operands, CoreNeverType))
  | [array] <- operands = select state array
  | otherwise = (state, Just (withEffects arityFailure, CoreNeverType))
 where
  expression = CoreExpression at
  arityFailure = argumentFailure blame at "E7003" "bytesOf expects one array"
  withEffects failure = expression CoreNeverType (CoreBlockValue (CoreBlock
    [CoreStatement (coreExpressionSpan operand) (CoreEvaluate operand) | operand <- operands] (Just failure)))
  select current array
    | Just selected <- mapRuntimeChoice current at CoreBytesType array
        (\ready held -> fmap (fmap fst) (select ready held)) = selected
    | CoreArrayType element <- coreExpressionType array
    , element == byteType = (current, Just (bytesFromArray at array, CoreBytesType))
    | CoreArrayType element <- coreExpressionType array =
        checkedByteArray blame at current array element
    | otherwise =
        let failure = expression CoreNeverType (CoreBlockValue
              (CoreBlock [CoreStatement at (CoreEvaluate array)] (Just arityFailure)))
         in (current, Just (failure, CoreNeverType))

checkedByteArray :: ArgumentBlame -> Span -> LowerState -> CoreExpression -> CoreType -> Lowered
checkedByteArray blame at state array element =
  let arrayKind = CoreArrayType byteType
      (withSource, source) = bindLocal state "" (coreExpressionType array)
      (withIndex, index) = bindLocal withSource "" intType
      (withOutput, output) = bindLocal withIndex "" arrayKind
      (withElement, item) = bindLocal withOutput "" element
      (entered, loop) = pushLoop Nothing withElement
      readAt = expression element (CoreIndex (readLocal source) (readLocal index))
      length' = expression intType (CoreArrayMethod ArrayLengthOf (readLocal source) [])
      condition = expression CoreBoolType (CoreBinary CoreLess (readLocal index) length')
      increment = expression intType (CoreBinary CoreAdd (readLocal index) (number 1))
      (after, byte) = checkedByte entered (readLocal item)
      pushed = expression arrayKind (CoreArrayMethod ArrayPushValue (readLocal output) [byte])
      body = CoreBlock [declare item readAt, statement (CoreAssign output pushed),
                statement (CoreAssign index increment)] Nothing
      steps = [declare source array, declare index (number 0), declare output (expression arrayKind (CoreArray [])),
                statement (CoreEvaluate (expression CoreUnitType (CoreWhileValue loop condition body)))]
      result = expression CoreBytesType
        (CoreBlockValue (CoreBlock steps (Just (bytesFromArray at (readLocal output)))))
   in (popLoop after, Just (result, CoreBytesType))
 where
  expression = CoreExpression at
  statement = CoreStatement at
  declare local value = statement (CoreDeclare local value)
  readLocal local = expression (coreLocalType local) (CoreReadLocal local)
  number value = expression intType (CoreIntegerLiteral PlatformSigned value)
  checkedByte current value
    | coreExpressionType value == byteType = (current, value)
    | Just (after, Just (selected, _)) <- mapRuntimeChoice current at byteType value
        (\ready item -> fmap Just (checkedByte ready item)) = (after, selected)
    | CoreIntegerType _ <- coreExpressionType value =
        let fits = expression CoreBoolType (CoreIntegerFits (UnsignedKind 8) value)
            byte = expression byteType (CoreIntegerConvert (UnsignedKind 8) value)
            message = append (append (literal "bytesOf received ") (expression CoreTextType (CoreDisplay value)))
              (literal ", which is not a byte")
            failure = argumentFailureWith blame at "E7004"
              (Just "mask the value to eight bits before building a byte sequence") message
         in (current, expression byteType (CoreIfValue fits (CoreBlock [] (Just byte)) failure))
    | otherwise = (current, argumentFailure blame at "E7001" "bytesOf expects an array of UInt8")
  literal = expression CoreTextType . CoreTextLiteral
  append left right = expression CoreTextType (CoreBinary CoreAdd left right)

{-| What `bytesOf` makes of a lowered `Array[UInt8]`. -}
bytesFromArray :: Span -> CoreExpression -> CoreExpression
bytesFromArray at array = CoreExpression at CoreBytesType (CoreBytesMethod BytesOfArray array [])

lowerBytesOn :: LowerExpression -> LowerState -> Span -> CoreExpression -> Text -> [Located Expression] -> Lowered
lowerBytesOn lower state at receiver member arguments = case collectArguments lower state arguments of
  (after, Nothing) -> refused after
  (after, Just operands)
    | Just (parameters, invoke) <- operation ->
        let failure = argumentFailure (methodArgumentBlame state) at "E7003" ("wrong arguments for byte method " <> member)
            apply ready (bytes : arguments') = invoke ready bytes arguments'
            apply ready [] = refused ready
         in callWithRuntimeArguments at failure (ExactSlot CoreBytesType : map positionSlot parameters) apply after (receiver : operands)
    | otherwise -> halt at ("a call to " <> member <> " on Bytes") after
 where
  operation = case member of
    "isEmpty" -> Just ([], \ready bytes _ ->
      built ready CoreBoolType (CoreBinary CoreEqual (method intType BytesLengthOf bytes []) (number 0)))
    "at" -> Just ([intType], \ready bytes -> \case
      [index] -> at' ready (clampedPosition at index) bytes
      _ -> refused ready)
    "toText" -> Just ([], \ready bytes _ -> asText ready bytes)
    "strided" -> Just ([intType, intType, intType], \ready bytes -> \case
      [offset, width, stride] -> strided ready (offset, width, stride) bytes
      _ -> refused ready)
    _ -> do
      (name, parameters, result) <- lookup member direct
      pure (parameters, \ready bytes operands -> built ready result
        (CoreBytesMethod name bytes (zipWith prepare parameters operands)))

  prepare parameter operand
    | parameter == intType = clampedPosition at operand
    | otherwise = operand

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
  -- Each method's Option is fixed by the method, whatever facts the call kept.
  optionOf payload = CoreSumType "Option" [payload]
  -- at: Some(byte) when 0 <= index < length, None otherwise.
  at' current index bytes = let option = optionOf byteType in
      let (withIndex, indexLocal) = bindLocal current "" intType
          (withBytes, bytesLocal) = bindLocal withIndex "" CoreBytesType
          inside = compare' CoreAnd (compare' CoreGreaterOrEqual (reading indexLocal) (number 0))
            (compare' CoreLess (reading indexLocal) (method intType BytesLengthOf (reading bytesLocal) []))
          some = CoreExpression at option (CoreConstruct "Some" [("0", method byteType BytesAtIndex (reading bytesLocal) [reading indexLocal])])
          none = CoreExpression at option (CoreConstruct "None" [])
          choice = CoreExpression at option (CoreIfValue inside (CoreBlock [] (Just some)) none)
       in (withBytes, Just (CoreExpression at option (CoreBlockValue (CoreBlock
            [CoreStatement at (CoreDeclare bytesLocal bytes), CoreStatement at (CoreDeclare indexLocal index)] (Just choice))), option))
  -- strided: the receiver, then the operands, run into locals; None for a negative offset or width, a stride below one or a
  -- width wider than the stride; otherwise Some of the gathered groups.
  strided current (offsetCore, widthCore, strideCore) bytes = let option = optionOf CoreBytesType in
      let (withOffset, offsetLocal) = bindLocal current "" (coreExpressionType offsetCore)
          (withWidth, widthLocal) = bindLocal withOffset "" (coreExpressionType widthCore)
          (withStride, strideLocal) = bindLocal withWidth "" (coreExpressionType strideCore)
          (withBytes, bytesLocal) = bindLocal withStride "" CoreBytesType
          (offset, width, stride) = (reading offsetLocal, reading widthLocal, reading strideLocal)
          shaped = foldr1 (compare' CoreAnd)
            [ atLeast offset 0, atLeast width 0, atLeast stride 1
            , integerComparison at CoreLessOrEqual width stride ]
          bounds = map (clampedPosition at) [offset, width, stride]
          some = CoreExpression at option
            (CoreConstruct "Some" [("0", method CoreBytesType BytesStridedOf (reading bytesLocal) bounds)])
          none = CoreExpression at option (CoreConstruct "None" [])
          choice = CoreExpression at option (CoreIfValue shaped (CoreBlock [] (Just some)) none)
          declared = [CoreStatement at (CoreDeclare local operand)
            | (local, operand) <- [(bytesLocal, bytes), (offsetLocal, offsetCore), (widthLocal, widthCore), (strideLocal, strideCore)]]
       in (withBytes, Just (CoreExpression at option (CoreBlockValue (CoreBlock declared (Just choice))), option))
  atLeast operand n = integerComparison at CoreGreaterOrEqual operand $ case coreExpressionType operand of
    kind@(CoreIntegerType integer) -> CoreExpression at kind (CoreIntegerLiteral integer n)
    _ -> number n
  -- toText: Some of the same storage when it is valid UTF-8, None otherwise.
  asText current bytes = let option = optionOf CoreTextType in
      let (withBytes, bytesLocal) = bindLocal current "" CoreBytesType
          some = CoreExpression at option (CoreConstruct "Some" [("0", method CoreTextType BytesAsText (reading bytesLocal) [])])
          none = CoreExpression at option (CoreConstruct "None" [])
          choice = CoreExpression at option (CoreIfValue (method CoreBoolType BytesIsText (reading bytesLocal) []) (CoreBlock [] (Just some)) none)
       in (withBytes, Just (CoreExpression at option (CoreBlockValue (CoreBlock [CoreStatement at (CoreDeclare bytesLocal bytes)] (Just choice))), option))
