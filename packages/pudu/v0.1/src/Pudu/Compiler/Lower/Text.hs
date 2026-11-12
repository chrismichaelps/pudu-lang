{-| @Pudu.Compiler.Lower.Text — built-in Str and Char methods on a lowered receiver. -}
module Pudu.Compiler.Lower.Text (lowerTextMethod, lowerTextPrimitive, textCallable) where

import Data.Text (Text)
import Pudu.Compiler.Lower.Array (stopped)
import Pudu.Compiler.Lower.Control (expressionIsPrintValued)
import Pudu.Compiler.Lower.Decimal (lowerTextToDecimal)
import Pudu.Compiler.Lower.State (LowerContext (..), LowerState (..), bindLocal, halt, intType, refused)
import Pudu.Compiler.Lower.Types (typeForSpan)
import Pudu.Core
import Pudu.FloatLiteral (FloatWidth (..))
import Pudu.Frontend.Syntax (Expression, Located (..))
import Pudu.IntegerLiteral (IntegerKind (PlatformSigned, UnsignedKind))
import Pudu.Source (Span)

type LowerExpression = LowerState -> Located Expression -> (LowerState, Maybe (CoreExpression, CoreType))

{-| The receiver's type decides whether this is a Str method at all. Str
    answers its own methods before any impl, so there is no lookup to make. -}
lowerTextMethod :: LowerExpression -> LowerState -> Span -> Located Expression -> Text -> [Located Expression]
  -> (LowerState, Maybe (CoreExpression, CoreType))
lowerTextMethod lower state at receiver member arguments = case lower state receiver of
  (after, Nothing) -> refused after
  (after, Just (coreReceiver, CoreTextType))
    | null arguments, Just reading <- lookup member parsers -> parsed after coreReceiver reading
    -- The UTF-8 bytes are the text's own storage.
    | null arguments, member == "toBytes" -> built after (CoreBytesMethod BytesFromText coreReceiver []) CoreBytesType
    | null arguments, member == "toDecimal" -> lowerTextToDecimal after at coreReceiver
    | otherwise -> case lookup member methods of
    Nothing -> halt at ("the Str method '" <> member <> "'") after
    Just (name, parameters, result) -> collect after [] (zip parameters arguments)
      where
        collect current done []
          | length arguments /= length parameters =
              halt at ("a call to " <> member <> " with this many arguments") current
          | any ((== CoreNeverType) . coreExpressionType) (reverse done <> [coreReceiver]) =
              let operands = reverse done <> [coreReceiver]
               in built current (CoreBlockValue (CoreBlock
                    [CoreStatement (coreExpressionSpan operand) (CoreEvaluate operand) | operand <- operands] Nothing))
                    CoreNeverType
          | otherwise = built current (CoreTextMethod name coreReceiver (reverse done)) result
        collect current done ((expected, argument) : rest) = case lower current argument of
          (next, Nothing) -> refused next
          (next, Just (core, kind))
            | expressionIsPrintValued core -> halt (locatedSpan argument) "a Result[(), Str] method argument" next
            | kind == expected || kind == CoreNeverType -> collect next (core : done) rest
            | otherwise -> halt (locatedSpan argument) ("a " <> coreTypeName kind <> " argument to " <> member) next
  (after, Just (coreReceiver, CoreNeverType)) -> effects after [] arguments
    where
      -- The receiver still runs after the arguments, and it is what stops the call.
      effects current done [] = built current (CoreBlockValue (CoreBlock
        [CoreStatement (coreExpressionSpan operand) (CoreEvaluate operand) | operand <- reverse done <> [coreReceiver]] Nothing))
        CoreNeverType
      effects current done (argument : rest) = case lower current argument of
        (next, Nothing) -> refused next
        (next, Just (core, _))
          | expressionIsPrintValued core -> halt (locatedSpan argument) "a Result[(), Str] method argument" next
          | otherwise -> effects next (core : done) rest
  (after, Just (coreReceiver, CoreCharType)) -> case (member, arguments) of
    -- Char answers these two before any impl, as readCharMember does.
    ("code", []) -> built after (CoreCharCode coreReceiver) intType
    ("toText", []) -> built after (CoreDisplay coreReceiver) CoreTextType
    _ | member `elem` ["code", "toText"] -> halt at ("a call to " <> member <> " with this many arguments") after
      | otherwise -> halt at ("the Char method '" <> member <> "'") after
  (after, Just (_, kind)) -> halt at ("methods on " <> coreTypeName kind) after
 where
  built current shape kind = (current, Just (CoreExpression at kind shape, kind))

  -- toInt/toFloat: the text goes into a local, then a test picks Some(read)
  -- or None, using the Option the checker gave the call.
  parsed current coreReceiver (test, readName, valueType) = case typeForSpan (contextTypes (lowerContext current)) at of
    Just kind@(CoreSumType _ _) ->
      let (withHeld, held) = bindLocal current "" CoreTextType
          expression shape' kind' = CoreExpression at kind' shape'
          text' = expression (CoreReadLocal held) CoreTextType
          some = expression (CoreConstruct "Some" [("0", expression (CoreTextMethod readName text' []) valueType)]) kind
          none = expression (CoreConstruct "None" []) kind
          choice = expression (CoreIfValue (expression (CoreTextMethod test text' []) CoreBoolType) (CoreBlock [] (Just some)) none) kind
       in built withHeld (CoreBlockValue (CoreBlock [CoreStatement at (CoreDeclare held coreReceiver)] (Just choice))) kind
    _ -> halt at ("an Option result of " <> member <> " without a native form") current

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
  pure (CoreFunctionType parameters result, textAnswer primitive parameters result)

lowerTextPrimitive :: LowerExpression -> LowerState -> Span -> Text -> [Located Expression] -> Maybe Lowered
lowerTextPrimitive lower state at name arguments = do
  (primitive, parameters, result) <- lookup name textPrimitives
  pure $ if length arguments /= length parameters then halt at "a text-view primitive with the wrong arity" state
    else go primitive parameters result state [] (zip parameters arguments)
 where
  go primitive parameters result current done []
    | typeForSpan (contextTypes (lowerContext current)) at == Just result =
        textAnswer primitive parameters result current at (reverse done)
    | otherwise = halt at "a text-view primitive without its exact checked result" current
  go primitive parameters result current done ((expected, argument) : rest) = case lower current argument of
    (after, Nothing) -> refused after
    (after, Just (core, CoreNeverType)) -> (after, Just (stopped at (reverse (core : done)), CoreNeverType))
    (after, Just (core, kind))
      | kind == expected -> go primitive parameters result after (core : done) rest
      | otherwise -> halt (locatedSpan argument) "a text-view argument without its checked carrier" after

textAnswer :: TextPrimitive -> [CoreType] -> CoreType -> LowerState -> Span -> [CoreExpression] -> Lowered
textAnswer primitive parameters result state at cores
  | map coreExpressionType cores /= parameters = halt at "a text-view value without its checked arguments" state
  | otherwise = case given of
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
