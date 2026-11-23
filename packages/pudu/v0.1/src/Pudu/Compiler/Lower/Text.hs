{-| @Pudu.Compiler.Lower.Text — built-in Str and Char methods on a lowered receiver. -}
module Pudu.Compiler.Lower.Text (lowerTextMethod, lowerTextPrimitive, textCallable) where

import Data.Text (Text)
import Pudu.Compiler.Lower.Arguments
  ( ArgumentBlame (..), ArgumentSlot (ExactSlot), argumentFailure, callWithRuntimeArguments
  , clampedPosition, collectArguments, exactPosition, integerComparison, methodArgumentBlame, positionSlot
  )
import Pudu.Compiler.Lower.Bytes (lowerBytesOn)
import Pudu.Compiler.Lower.Dynamic (mapRuntimeChoice, missingRuntimeMember, preserveRuntimeResult)
import Pudu.Compiler.Lower.Decimal (lowerTextToDecimal)
import Pudu.Compiler.Lower.State (LowerContext (..), LowerState (..), bindLocal, halt, intType, refused)
import Pudu.Compiler.Lower.Types (typeForSpan)
import Pudu.Core
import Pudu.Eval.Bytes (bytesMethods)
import Pudu.FloatLiteral (FloatWidth (..))
import Pudu.Frontend.Syntax (Expression, Located (..))
import Pudu.IntegerLiteral (IntegerKind (PlatformSigned, UnsignedKind))
import Pudu.Source (Span)

type LowerExpression = LowerState -> Located Expression -> (LowerState, Maybe (CoreExpression, CoreType))

{-| The receiver's type decides whether this is a Str method at all. Str
    answers its own methods before any impl, so there is no lookup to make. -}
lowerTextMethod :: LowerExpression -> (LowerState -> CoreExpression -> Maybe Lowered)
  -> LowerState -> Span -> Span -> Located Expression -> Text -> [Located Expression]
  -> (LowerState, Maybe (CoreExpression, CoreType))
lowerTextMethod lower fallback state at callee receiver member arguments = case lower state receiver of
  (after, Nothing) -> refused after
  (after, Just (coreReceiver, _)) -> select False after coreReceiver
 where
  select selected current held
    | kind == CoreNeverType = (current, Just (held, kind))
    | Just (after, dispatch) <- mapRuntimeChoice current at CoreNeverType held
        (\ready value -> fmap (fmap fst) (select True ready value)) =
        (after, do
          (answer, _) <- dispatch
          let types = contextTypes (lowerContext after)
              result = maybe answer (\checked -> preserveRuntimeResult checked answer) (typeForSpan types at)
          pure (result, coreExpressionType result))
    | kind == CoreBytesType, member `elem` map fst bytesMethods =
        lowerBytesOn lower current at held member arguments
    | kind == CoreTextType = textMethod selected current held
    | kind == CoreCharType, member == "code" =
        checked "wrong arguments for a character method" [] current held
          (\ready receiver' _ -> built ready (CoreCharCode receiver') intType)
    | kind == CoreCharType, member == "toText" = displayWith "wrong arguments for a character method" current held
    | member == "toText", selected, Just implementation <- fallback current held = implementation
    | member == "toText" = displayWith "display expects one value" current held
    | otherwise = missing selected current held
   where
    kind = coreExpressionType held
  missing selected current held
    | selected, Just implementation <- fallback current held = implementation
    | selected =
        let failure = missingRuntimeMember callee member held
         in (current, Just (failure, CoreNeverType))
    | otherwise = halt at ("the method '" <> member <> "' on " <> coreTypeName (coreExpressionType held)) current

  textMethod selected current held
    | member == "toBytes" = call [] current held
        (\ready receiver' _ -> built ready (CoreBytesMethod BytesFromText receiver' []) CoreBytesType)
    | member == "toDecimal" = call [] current held
        (\ready receiver' _ -> lowerTextToDecimal ready at receiver')
    | member == "toText" = displayWith "display expects one value" current held
    | Just parser <- lookup member parsers = call [] current held
        (\ready receiver' _ -> parsed ready receiver' parser)
    | Just (method, parameters, result) <- lookup member methods = call parameters current held
        (textOperation method result)
    | otherwise = missing selected current held
  textOperation method result current held operands =
    let clamp value
          | CoreIntegerType _ <- coreExpressionType value = clampedPosition at value
          | otherwise = value
        applied = CoreTextMethod method held (map clamp operands)
     in case (method, operands) of
          (TextRepeat, [count]) | coreExpressionType count /= intType ->
            let (fits, _) = exactPosition at count
                positive = integerComparison at CoreGreater count (CoreExpression at intType (CoreIntegerLiteral PlatformSigned 0))
                expression = CoreExpression at
                oversized = expression CoreBoolType (CoreBinary CoreAnd (expression CoreBoolType (CoreNot fits)) positive)
                empty = expression CoreBoolType (CoreTextMethod TextIsEmpty held [])
                failure = argumentFailure (methodArgumentBlame current) at "E7004"
                  "repeated text exceeds the runtime size limit"
                fallback' = expression CoreTextType (CoreIfValue empty
                  (CoreBlock [] (Just (expression CoreTextType (CoreTextLiteral "")))) failure)
             in built current (CoreIfValue oversized (CoreBlock [] (Just fallback')) (expression result applied)) result
          _ -> built current applied result
  call = checked ("wrong arguments for " <> member)
  displayWith message current held = checked message [] current held
    (\ready receiver' _ -> built ready (CoreDisplay receiver') CoreTextType)
  checked message expected current held invoke = case collectArguments lower current arguments of
    (after, Nothing) -> refused after
    (after, Just operands) ->
      let failure = argumentFailure (methodArgumentBlame current) at "E7012" message
          apply ready (target : parameters) = invoke ready target parameters
          apply ready [] = refused ready
       in callWithRuntimeArguments at failure (ExactSlot (coreExpressionType held) : map positionSlot expected) apply after (held : operands)
  built current shape kind = (current, Just (CoreExpression at kind shape, kind))

  -- toInt/toFloat: the text goes into a local, then a test picks Some(read)
  -- or None, using the Option the checker gave the call.
  -- The parser's Option is fixed by the parser, whatever facts the call kept.
  parsed current coreReceiver (test, readName, valueType) =
      let kind = CoreSumType "Option" [valueType]
          (withHeld, held) = bindLocal current "" CoreTextType
          expression shape' kind' = CoreExpression at kind' shape'
          text' = expression (CoreReadLocal held) CoreTextType
          some = expression (CoreConstruct "Some" [("0", expression (CoreTextMethod readName text' []) valueType)]) kind
          none = expression (CoreConstruct "None" []) kind
          choice = expression (CoreIfValue (expression (CoreTextMethod test text' []) CoreBoolType) (CoreBlock [] (Just some)) none) kind
       in built withHeld (CoreBlockValue (CoreBlock [CoreStatement at (CoreDeclare held coreReceiver)] (Just choice))) kind

parsers :: [(Text, (CoreTextMethodName, CoreTextMethodName, CoreType))]
parsers =
  [ ("toInt", (TextParsesInt, TextIntOf, intType))
  , ("toFloat", (TextParsesFloat, TextFloatOf, CoreFloatType Float64Width))
  ]

methods :: [(Text, (CoreTextMethodName, [CoreType], CoreType))]
methods =
  [ ("length", (TextLength, [], intType))
  , ("isEmpty", (TextIsEmpty, [], CoreBoolType))
  , ("contains", (TextContains, [CoreTextType], CoreBoolType))
  , ("startsWith", (TextStartsWith, [CoreTextType], CoreBoolType))
  , ("endsWith", (TextEndsWith, [CoreTextType], CoreBoolType))
  , ("indexOf", (TextIndexOf, [CoreTextType], intType))
  , ("spanOf", (TextSpanOf, [CoreTextType], intType))
  , ("spanNotOf", (TextSpanNotOf, [CoreTextType], intType))
  , ("drop", (TextDrop, [intType], CoreTextType))
  , ("take", (TextTake, [intType], CoreTextType))
  , ("slice", (TextSlice, [intType, intType], CoreTextType))
  , ("repeat", (TextRepeat, [intType], CoreTextType))
  , ("reverse", (TextReverse, [], CoreTextType))
  , ("escapeHtml", (TextEscapeHtml, [], CoreTextType))
  , ("replace", (TextReplace, [CoreTextType, CoreTextType], CoreTextType))
  , ("trim", (TextTrim, [], CoreTextType))
  , ("toUpper", (TextToUpper, [], CoreTextType))
  , ("toLower", (TextToLower, [], CoreTextType))
  , ("charAt", (TextCharAt, [intType], CoreCharType))
  , ("split", (TextSplit, [CoreTextType], CoreArrayType CoreTextType))
  , ("lines", (TextLines, [], CoreArrayType CoreTextType))
  , ("chars", (TextChars, [], CoreArrayType CoreCharType))
  ]

{-| The source primitive chooses a checked read; Option construction stays in Core. -}
data TextPrimitive = ByteSize | ByteAt | ByteSlice | ByteFind | ByteFindLast | ScalarAt

type Lowered = (LowerState, Maybe (CoreExpression, CoreType))

textPrimitives :: [(Text, (TextPrimitive, [CoreType], CoreType))]
textPrimitives =
  [ ("textByteSize", (ByteSize, [CoreTextType], intType))
  , ("textByteAt", (ByteAt, [CoreTextType, intType], optional byte))
  , ("textByteSlice", (ByteSlice, [CoreTextType, intType, intType], optional CoreTextType))
  , ("textByteFind", (ByteFind, [CoreTextType, CoreTextType, intType], optional intType))
  , ("textByteFindLast", (ByteFindLast, [CoreTextType, CoreTextType], optional intType))
  , ("textScalarAt", (ScalarAt, [CoreTextType, intType], optional (CoreTupleType [CoreCharType, intType])))
  ]
 where
  byte = CoreIntegerType (UnsignedKind 8)
  optional kind = CoreSumType "Option" [kind]

{-| A value reference supplies a function fact, not an Option result fact. -}
textCallable :: Text -> Maybe (CoreType, LowerState -> Span -> [CoreExpression] -> Lowered)
textCallable name = do
  (primitive, parameters, result) <- lookup name textPrimitives
  pure (CoreFunctionType parameters result, selectTextPrimitive AtCaller primitive parameters result)

lowerTextPrimitive :: LowerExpression -> LowerState -> Span -> Text -> [Located Expression] -> Maybe Lowered
lowerTextPrimitive lower state at name arguments = do
  (primitive, parameters, result) <- lookup name textPrimitives
  pure $ case collectArguments lower state arguments of
    (after, Nothing) -> refused after
    (after, Just operands) -> selectTextPrimitive AtInvocation primitive parameters result after at operands

selectTextPrimitive :: ArgumentBlame -> TextPrimitive -> [CoreType] -> CoreType -> LowerState -> Span -> [CoreExpression] -> Lowered
selectTextPrimitive blame primitive parameters result state at operands =
  callWithRuntimeArguments at failure (map positionSlot parameters) apply state operands
 where
  apply current held =
    let adjusted = zipWith position parameters held
        checks = [fits | Just fits <- map fst adjusted]
        (next, result') = textAnswer primitive result at current (map snd adjusted)
        guardPosition answer = case checks of
          first : rest ->
            let allFit = foldl' (\a b -> CoreExpression at CoreBoolType (CoreBinary CoreAnd a b)) first rest
                none = CoreExpression at result (CoreConstruct "None" [])
             in CoreExpression at result (CoreIfValue allFit (CoreBlock [] (Just answer)) none)
          [] -> answer
     in (next, (\(answer, _) -> (guardPosition answer, result)) <$> result')
  position expected given
    | expected == intType, coreExpressionType given /= intType =
        let (fits, converted) = exactPosition at given in (Just fits, converted)
    | otherwise = (Nothing, given)
  failure
    | length operands == length parameters = argumentFailure blame at "E7001" shapeMessage
    | otherwise = argumentFailure blame at "E7003" arityMessage
  (shapeMessage, arityMessage) = case primitive of
    ByteSize -> ("textByteSize expects a Str", "textByteSize expects one argument")
    ByteAt -> ("textByteAt expects a Str and an Int offset", "textByteAt expects two arguments")
    ByteSlice -> ("textByteSlice expects a Str and two Int offsets", "textByteSlice expects three arguments")
    ByteFind -> ("textByteFind expects two Str values and an Int offset", "textByteFind expects three arguments")
    ByteFindLast -> ("textByteFindLast expects two Str values", "textByteFindLast expects two arguments")
    ScalarAt -> ("textScalarAt expects a Str and an Int offset", "textScalarAt expects two arguments")

textAnswer :: TextPrimitive -> CoreType -> Span -> LowerState -> [CoreExpression] -> Lowered
textAnswer primitive result at state cores = case given of
  text : arguments -> case (primitive, arguments) of
    (ByteSize, []) -> finish held declarations (method TextByteSize intType text [])
    (ByteAt, [index]) -> optional (method TextByteIndexValid CoreBoolType text [index])
      (method TextByteRead (CoreIntegerType (UnsignedKind 8)) text [index])
    (ByteSlice, [start, end]) -> optional (method TextByteSliceValid CoreBoolType text [start, end])
      (method TextByteSlice CoreTextType text [start, end])
    (ByteFind, [needle, start]) -> searched (method TextByteFind intType text [needle, start])
    (ByteFindLast, [needle]) -> searched (method TextByteFindLast intType text [needle])
    (ScalarAt, [index]) ->
      let valid = expression CoreBoolType (CoreBinary CoreAnd
            (method TextByteIndexValid CoreBoolType text [index])
            (method TextByteSliceValid CoreBoolType text [index, index]))
          scalar = method TextScalarRead CoreCharType text [index]
          width = method TextScalarWidth intType text [index]
       in optional valid (expression (CoreTupleType [CoreCharType, intType]) (CoreTuple [scalar, width]))
    _ -> halt at "a text-view primitive without its checked operand layout" state
  [] -> halt at "a text-view primitive without its text operand" state
 where
  (held, locals) = foldl' hold (state, []) cores
  hold (current, done) core = let (after, local) = bindLocal current "" (coreExpressionType core) in (after, done <> [local])
  declarations = [CoreStatement (coreExpressionSpan core) (CoreDeclare local core) | (local, core) <- zip locals cores]
  given = [expression (coreLocalType local) (CoreReadLocal local) | local <- locals]
  expression kind shape = CoreExpression at kind shape
  method name kind target operands = expression kind (CoreTextMethod name target operands)
  choice valid value = expression result (CoreIfValue valid
    (CoreBlock [] (Just (expression result (CoreConstruct "Some" [("0", value)])))) (expression result (CoreConstruct "None" [])))
  finish current statements answer = (current, Just (expression result (CoreBlockValue (CoreBlock statements (Just answer))), result))
  optional valid value = finish held declarations (choice valid value)
  searched query =
    let (after, local) = bindLocal held "" intType
        found = expression intType (CoreReadLocal local)
        nonnegative = expression CoreBoolType (CoreBinary CoreGreaterOrEqual found (expression intType (CoreIntegerLiteral PlatformSigned 0)))
     in finish after (declarations <> [CoreStatement at (CoreDeclare local query)]) (choice nonnegative found)
