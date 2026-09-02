{-| @Program.Eval.Builtin — implements the values the prelude wires in -}
module Pudu.Eval.Builtin
  ( Apply
  , callHashing
  , callArrayMethod
  , callCharFromCode
  , callCharMethod
  , callDecimal
  , callDisplay
  , callEffect
  , callMapMethod
  , callMapOf
  , callPanic
  , callSetMethod
  , callSetOf
  , callShow
  , callStringMethod
  , callConvertInteger
  , effectBuiltins
  , isDecimalBuiltin
  ) where

import Control.Monad (filterM, foldM)
import Data.Foldable (toList)
import qualified Data.Sequence as Seq
import Data.Text (Text)
import qualified Data.Text as Text
import Pudu.IntegerLiteral (integerKindFits, integerKindOf)
import Pudu.Eval.Bytes (bytesFromText)
import Pudu.Eval.Hash (hashOfValue, hmacSha256, pbkdf2Sha256, sha256)
import Pudu.Eval.HashMap (mixKey)
import Pudu.Eval.Effect (callEffect, effectBuiltins)
import Pudu.Eval.Keyed
import Pudu.Eval.Order (comparableValue)
import Pudu.Eval.Env
  ( Evaluator (..)
  , abortAt
  )
import Pudu.Source (Span)
import Pudu.Eval.Array
  ( arrayFromList
  , arrayToList
  , arrayLength
  , arrayIndex
  , arrayPush
  , arrayPop
  , arrayInsert
  , arrayRemove
  , arraySlice
  , arrayConcat
  , arrayReverse
  , arrayIndexOf
  , arrayContains
  )
import Pudu.FloatLiteral (FloatWidth (Float64Width))
import Pudu.DecimalLiteral
  ( Rounding (..)
  , decimalDivideWith
  , decimalFromInteger
  , decimalRound
  , decimalScaleOf
  , decimalToDouble
  , decimalToInteger
  , parseDecimalText
  )
import Pudu.Eval.Render (renderValue, valueKind)
import Pudu.Eval.Value
  ( ArrayMethod (..)
  , Builtin (..)
  , builtinName
  , intOf
  , CharMethod (..)
  , MapMethod (..)
  , SetMethod (..)
  , mapMethodName
  , setMethodName
  , StringMethod (..)
  , Value (..)
  , stringMethodName
  )

{-| @Eval.Builtin.Apply — applying a value as a function.

    `map`, `filter`, and `reduce` call back into whatever they were given, and
    dispatch needs those methods to answer a call. One of the two directions
    has to be an argument rather than an import, and this is that direction —
    the same shape the parser uses for its own mutual recursion. -}
type Apply = Span -> Value -> [Value] -> Evaluator Value

acceptByFunction :: Apply -> Span -> Value -> Value -> Evaluator Bool
acceptByFunction apply spanValue function element = do
  result <- apply spanValue function [element]
  case result of
    BoolValue flag -> pure flag
    _ -> abortAt (Just spanValue) "E7001" "filter predicate must return Bool" Nothing

{-| Render any value as the text a message should carry.

    The difference from `show` is text itself: `show` quotes a string so a
    printed `"1"` is never mistaken for the number, which is what a reader
    inspecting a value needs. A message being built wants the string's own
    content, and interpolation is a message being built. Everything that is not
    text or a character renders identically either way. -}
callDisplay :: Span -> [Value] -> Evaluator Value
callDisplay spanValue arguments = case arguments of
  [StrValue text] -> pure (StrValue text)
  [CharValue character] -> pure (StrValue (Text.singleton character))
  [value] -> pure (StrValue (renderValue value))
  _ -> abortAt (Just spanValue) "E7012" "display expects one value" Nothing

{-| Move an integer to another integer type, refusing what will not fit.

    It is the one integer operation that cannot be written in Pudu at all: every
    other one is arithmetic on values of a single type, and this one is the
    boundary between two.

    Answering `None` rather than truncating is the same rule checked arithmetic
    follows. A caller that wants the low bits of a value says so with a mask
    before converting. -}
callConvertInteger :: Span -> [Text] -> [Value] -> Evaluator Value
callConvertInteger spanValue names arguments = case (names, arguments) of
  (target : _, [IntValue _ value]) -> case integerKindOf target of
    Just kind
      | integerKindFits kind value -> pure (VariantValue "Some" [IntValue kind value])
      | otherwise -> pure (VariantValue "None" [])
    Nothing ->
      abortAt (Just spanValue) "E7012"
        (target <> " is not an integer type")
        (Just "convert to one of the integer types, such as UInt8 or Int64")
  ([], _) ->
    abortAt (Just spanValue) "E7012" "convertInteger needs the type to convert to"
      (Just "write it as a type argument, as in convertInteger[UInt8](value)")
  (_, [other]) ->
    abortAt (Just spanValue) "E7012"
      ("convertInteger moves between integers, not from a " <> valueKind other)
      Nothing
  _ -> abortAt (Just spanValue) "E7012" "convertInteger expects one value" Nothing

{-| Whether a built-in is one of the decimal primitives. -}
isDecimalBuiltin :: Builtin -> Bool
isDecimalBuiltin builtin =
  builtin
    `elem` [ DecimalOfBuiltin
           , DecimalFromIntBuiltin
           , DecimalScaleBuiltin
           , DecimalToIntBuiltin
           , DecimalToFloatBuiltin
           , DecimalDivideBuiltin
           , DecimalRoundBuiltin
           ]

{-| Apply a decimal primitive.

    The two that round take the mode as a code rather than a name, because a
    wired-in signature cannot mention a type a library declares. An unrecognised
    code is half-even, which is the mode `Std.Decimal` documents as the default
    and the only one that does not accumulate bias across many roundings. -}
callDecimal :: Span -> Builtin -> [Value] -> Evaluator Value
callDecimal spanValue builtin values = case (builtin, values) of
  (DecimalOfBuiltin, [StrValue text]) -> pure $ case parseDecimalText text of
    Just number -> VariantValue "Some" [DecimalValue number]
    Nothing -> VariantValue "None" []
  (DecimalFromIntBuiltin, [IntValue _ number]) ->
    pure (DecimalValue (decimalFromInteger number))
  (DecimalScaleBuiltin, [DecimalValue number]) ->
    pure (intOf (toInteger (decimalScaleOf number)))
  (DecimalToIntBuiltin, [DecimalValue number]) -> pure $ case decimalToInteger number of
    Just whole -> VariantValue "Some" [intOf whole]
    Nothing -> VariantValue "None" []
  (DecimalToFloatBuiltin, [DecimalValue number]) ->
    pure (FloatValue Float64Width (decimalToDouble number))
  (DecimalDivideBuiltin, [DecimalValue left, DecimalValue right, IntValue _ digits, IntValue _ mode]) ->
    pure $ case decimalDivideWith (fromInteger digits) (roundingOfCode mode) left right of
      Right number -> VariantValue "Some" [DecimalValue number]
      Left _ -> VariantValue "None" []
  (DecimalRoundBuiltin, [DecimalValue number, IntValue _ digits, IntValue _ mode]) ->
    pure (DecimalValue (decimalRound (fromInteger digits) (roundingOfCode mode) number))
  _ ->
    abortAt (Just spanValue) "E7012"
      (builtinName builtin <> " was given arguments it does not accept")
      Nothing

{-| The rounding mode a code selects, in the order `Std.Decimal` declares its
    `Rounding` cases. -}
roundingOfCode :: Integer -> Rounding
roundingOfCode code = case code of
  0 -> RoundUp
  1 -> RoundDown
  2 -> RoundCeiling
  3 -> RoundFloor
  4 -> RoundHalfUp
  5 -> RoundHalfDown
  _ -> RoundHalfEven

{-| Render any value as text.

    Every program that prints anything needs this, and nothing in the language
    can express it: rendering depends on the runtime representation, and a
    library written in the language cannot see one. It is the same rendering the
    prompt uses, so what a reader sees at the prompt and what their program
    prints agree.

    A function renders as a description rather than as its source. Its source is
    not a value, and printing something that looked like source would invite a
    reader to expect it back. -}
callShow :: Span -> [Value] -> Evaluator Value
callShow spanValue arguments = case arguments of
  [value] -> pure (StrValue (renderValue value))
  _ -> abortAt (Just spanValue) "E7012" "show expects one value" Nothing

{-| Build a map from an array of key and value pairs.

    A key must be comparable: a map keeps its entries in key order so that two
    maps built differently with the same entries are the same map, and a
    function has no order. The refusal is a diagnostic rather than a silent
    fallback to insertion order, which would make equality depend on how a map
    was assembled. -}
callMapOf :: Span -> [Value] -> Evaluator Value
callMapOf spanValue arguments = case arguments of
  [ArrayValue members] -> do
    entries <- mapM (pairOf spanValue) (toList members)
    case filter (not . comparableValue . fst) entries of
      (offender, _) : _ ->
        abortAt (Just spanValue) "E7008"
          ("a " <> valueKind offender <> " cannot be a map key")
          (Just "use a value the language can order, such as text, a number, or a tuple of those")
      [] -> pure (mapFromEntries entries)
  _ -> abortAt (Just spanValue) "E7012" "mapOf expects one array of pairs" Nothing

pairOf :: Span -> Value -> Evaluator (Value, Value)
pairOf spanValue value = case value of
  TupleValue [key, held] -> pure (key, held)
  _ -> abortAt (Just spanValue) "E7012" "mapOf expects an array of pairs" Nothing

{-| Build a set from an array of members, with the same ordering requirement a
    map places on its keys and for the same reason. -}
callSetOf :: Span -> [Value] -> Evaluator Value
callSetOf spanValue arguments = case arguments of
  [ArrayValue members] ->
    case filter (not . comparableValue) (toList members) of
      offender : _ ->
        abortAt (Just spanValue) "E7008"
          ("a " <> valueKind offender <> " cannot be a set member")
          (Just "use a value the language can order, such as text, a number, or a tuple of those")
      [] -> pure (setFromMembers (toList members))
  _ -> abortAt (Just spanValue) "E7012" "setOf expects one array" Nothing

{-| Apply a built-in map method. Every one answers with a new value. -}
callMapMethod :: Span -> MapMethod -> Value -> [Value] -> Evaluator Value
callMapMethod spanValue method receiver arguments = case (method, arguments) of
  (MapSize, []) -> pure (intOf (fromIntegral (mapSize receiver)))
  (MapIsEmpty, []) -> pure (BoolValue (mapSize receiver == 0))
  (MapGet, [key]) -> pure (optionOf (mapGet receiver key))
  (MapContainsKey, [key]) -> pure (BoolValue (mapContainsKey receiver key))
  (MapInsert, [key, held])
    | comparableValue key -> pure (mapInsert receiver key held)
    | otherwise -> unorderableKey spanValue key "map key"
  (MapRemove, [key]) -> pure (mapRemove receiver key)
  (MapKeys, []) -> pure (ArrayValue (Seq.fromList (mapKeys receiver)))
  (MapValues, []) -> pure (ArrayValue (Seq.fromList (map snd (mapEntries receiver))))
  (MapEntries, []) ->
    pure (ArrayValue (Seq.fromList [TupleValue [key, held] | (key, held) <- mapEntries receiver]))
  (MapMerge, [other@(MapValue _)]) -> pure (mapMerge receiver other)
  _ ->
    abortAt (Just spanValue) "E7012"
      ("wrong arguments for " <> mapMethodName method) Nothing

{-| Apply a built-in set method. -}
callSetMethod :: Span -> SetMethod -> Value -> [Value] -> Evaluator Value
callSetMethod spanValue method receiver arguments = case (method, arguments) of
  (SetSize, []) -> pure (intOf (fromIntegral (setSize receiver)))
  (SetIsEmpty, []) -> pure (BoolValue (setIsEmpty receiver))
  (SetContains, [value]) -> pure (BoolValue (setContains receiver value))
  (SetInsert, [value])
    | comparableValue value -> pure (setInsert receiver value)
    | otherwise -> unorderableKey spanValue value "set member"
  (SetRemove, [value]) -> pure (setRemove receiver value)
  (SetToArray, []) -> pure (ArrayValue (Seq.fromList (setMembers receiver)))
  (SetUnion, [other@(SetValue _)]) -> pure (setUnion receiver other)
  (SetIntersect, [other@(SetValue _)]) -> pure (setIntersect receiver other)
  (SetDifference, [other@(SetValue _)]) -> pure (setDifference receiver other)
  _ ->
    abortAt (Just spanValue) "E7012"
      ("wrong arguments for " <> setMethodName method) Nothing

unorderableKey :: Span -> Value -> Text -> Evaluator Value
unorderableKey spanValue value described =
  abortAt (Just spanValue) "E7008"
    ("a " <> valueKind value <> " cannot be a " <> described)
    (Just "use a value the language can order, such as text, a number, or a tuple of those")

{-| A lookup that may find nothing, as the language's own absence carrier. -}
optionOf :: Maybe Value -> Value
optionOf found = case found of
  Just value -> VariantValue "Some" [value]
  Nothing -> VariantValue "None" []

{-| Turn a scalar value into a character.

    Not every integer is a Unicode scalar value: the surrogate range and
    anything past U+10FFFF are not, so the answer is an `Option` rather than a
    character the program would then carry around as a lie. -}
callCharFromCode :: Span -> [Value] -> Evaluator Value
callCharFromCode spanValue arguments = case arguments of
  [IntValue _ code]
    | code >= 0
    , code <= 0x10FFFF
    , not (code >= 0xD800 && code <= 0xDFFF) ->
        pure (VariantValue "Some" [CharValue (toEnum (fromInteger code))])
    | otherwise -> pure (VariantValue "None" [])
  _ ->
    abortAt (Just spanValue) "E7012" "charFromCode expects one integer" Nothing

{-| Apply a built-in character method. -}
callCharMethod :: Span -> CharMethod -> Value -> [Value] -> Evaluator Value
callCharMethod spanValue method receiver arguments = case (method, receiver, arguments) of
  (CharCode, CharValue character, []) -> pure (intOf (fromIntegral (fromEnum character)))
  (CharToText, CharValue character, []) -> pure (StrValue (Text.singleton character))
  _ -> abortAt (Just spanValue) "E7012" "wrong arguments for a character method" Nothing

{-| Apply a built-in text method.

    Every one answers with a new value: text is a value, and a method that
    changed its receiver would make two names for one string disagree. Indices
    count Unicode scalars, not bytes, so `charAt` and `slice` agree with what a
    reader counting characters expects — the same choice indexing already makes.

    An index outside the text is `E7004` rather than a clamped or empty answer.
    A silent clamp turns a logic error into wrong output that looks correct. -}
callStringMethod :: Span -> StringMethod -> Value -> [Value] -> Evaluator Value
callStringMethod spanValue method receiver arguments = case receiver of
  StrValue text -> apply text
  _ -> abortAt (Just spanValue) "E7001" "not text" Nothing
 where
  apply text = case (method, arguments) of
    (StringLength, []) -> pure (intOf (fromIntegral (Text.length text)))
    (StringIsEmpty, []) -> pure (BoolValue (Text.null text))
    (StringCharAt, [IntValue _ index]) -> charAt text index
    (StringIndexOf, [StrValue needle]) -> pure (intOf (indexOfText text needle))
    (StringContains, [StrValue needle]) -> pure (BoolValue (Text.isInfixOf needle text))
    (StringStartsWith, [StrValue needle]) -> pure (BoolValue (Text.isPrefixOf needle text))
    (StringEndsWith, [StrValue needle]) -> pure (BoolValue (Text.isSuffixOf needle text))
    {-| `drop` and `take` cost what they move, not what the text holds, which
        is what lets a parser carry the text it has not read yet and advance
        through a file in linear time. Indexing walks from the start, so a
        parser that kept a position into the whole text paid for every
        character it had already passed. -}
    (StringDrop, [IntValue _ count])
      | count < 0 -> outOfRange "a drop count cannot be negative"
      | otherwise -> pure (StrValue (Text.drop (fromInteger count) text))
    (StringTake, [IntValue _ count])
      | count < 0 -> outOfRange "a take count cannot be negative"
      | otherwise -> pure (StrValue (Text.take (fromInteger count) text))
    {-| How long a run at the front is made only of the given characters, or
        only of characters outside them. A run scanned in one step costs one
        call rather than one call for every character it covers, which is the
        difference between reading a line and reading a file — the set is the
        same vocabulary `oneOf` and `noneOf` already take. -}
    (StringSpanOf, [StrValue accepted]) -> pure (spanLength (`Text.elem` accepted) text)
    (StringSpanNotOf, [StrValue rejected]) ->
      pure (spanLength (not . (`Text.elem` rejected)) text)
    (StringSlice, [IntValue _ from, IntValue _ to]) -> slice text from to
    (StringTrim, []) -> pure (StrValue (Text.strip text))
    (StringToUpper, []) -> pure (StrValue (Text.toUpper text))
    (StringToLower, []) -> pure (StrValue (Text.toLower text))
    (StringReplace, [StrValue needle, StrValue replacement])
      | Text.null needle -> pure (StrValue text)
      | otherwise -> pure (StrValue (Text.replace needle replacement text))
    (StringRepeat, [IntValue _ count])
      | count < 0 -> outOfRange "a repeat count cannot be negative"
      | otherwise -> pure (StrValue (Text.replicate (fromInteger count) text))
    (StringSplit, [StrValue separator])
      | Text.null separator -> pure (textArray (Text.chunksOf 1 text))
      | otherwise -> pure (textArray (Text.splitOn separator text))
    (StringToBytes, []) -> pure (bytesFromText text)
    (StringChars, []) -> pure (ArrayValue (Seq.fromList (map CharValue (Text.unpack text))))
    (StringLines, []) -> pure (textArray (Text.lines text))
    (StringReverse, []) -> pure (StrValue (Text.reverse text))
    _ -> wrongStringArity (stringMethodName method)

  textArray = ArrayValue . Seq.fromList . map StrValue

  spanLength holds = intOf . fromIntegral . Text.length . Text.takeWhile holds

  charAt text index
    | index < 0 || index >= fromIntegral (Text.length text) =
        outOfRange "index out of range"
    | otherwise = pure (CharValue (Text.index text (fromInteger index)))

  {-| A slice is clamped at the end and refused at the start.

      A `to` beyond the text is the ordinary way to ask for "the rest", so
      clamping it answers the question. A negative `from`, or a `from` after
      `to`, is arithmetic that went wrong, and answering it would hide that. -}
  slice text from to
    | from < 0 = outOfRange "a slice cannot start before the text"
    | to < from = outOfRange "a slice cannot end before it starts"
    | otherwise =
        pure
          ( StrValue
              ( Text.take
                  (fromInteger (to - from))
                  (Text.drop (fromInteger from) text)
              )
          )

  outOfRange message = abortAt (Just spanValue) "E7004" message Nothing

  wrongStringArity name =
    abortAt (Just spanValue) "E7012"
      ("wrong arguments for " <> name) Nothing

{-| Where one text first occurs inside another, or -1 when it does not.

    -1 rather than `Option[Int]` because the array method of the same name
    already answers that way, and one vocabulary answering two ways would be
    worse than either answer. -}
indexOfText :: Text -> Text -> Integer
indexOfText text needle = case Text.breakOn needle text of
  (before, rest)
    | Text.null rest, not (Text.null needle) -> -1
    | otherwise -> fromIntegral (Text.length before)

{-| Apply a built-in array method. Each method has fixed arity and semantics
    defined in [[Eval Array]]. -}
callArrayMethod :: Apply -> Span -> ArrayMethod -> Value -> [Value] -> Evaluator Value
callArrayMethod apply spanValue method receiver arguments = case method of
  ArrayLength -> case arguments of
    [] -> case arrayLength receiver of
      Just len -> pure (intOf (fromIntegral len))
      Nothing -> abortAt (Just spanValue) "E7001" "not an array" Nothing
    _ -> wrongArity "length" 0
  ArrayGet -> case arguments of
    [IntValue _ index] -> case arrayIndex receiver (fromInteger index) of
      Just value -> pure value
      Nothing -> abortAt (Just spanValue) "E7004" "index out of range" Nothing
    _ -> wrongArity "get" 1
  ArrayIndexOf -> case arguments of
    [target] -> pure (intOf (fromIntegral (arrayIndexOf receiver target)))
    _ -> wrongArity "indexOf" 1
  ArrayContains -> case arguments of
    [target] -> pure (BoolValue (arrayContains receiver target))
    _ -> wrongArity "contains" 1
  ArrayPush -> case arguments of
    [value] -> pure (arrayPush receiver value)
    _ -> wrongArity "push" 1
  ArrayPop -> case arguments of
    [] -> pure (arrayPop receiver)
    _ -> wrongArity "pop" 0
  ArrayInsert -> case arguments of
    [IntValue _ index, value] -> pure (arrayInsert receiver (fromInteger index) value)
    _ -> wrongArity "insert" 2
  ArrayRemove -> case arguments of
    [IntValue _ index] -> pure (arrayRemove receiver (fromInteger index))
    _ -> wrongArity "remove" 1
  ArraySlice -> case arguments of
    [IntValue _ start, IntValue _ end'] -> pure (arraySlice receiver (fromInteger start) (fromInteger end'))
    _ -> wrongArity "slice" 2
  ArrayConcat -> case arguments of
    [other@(ArrayValue _)] -> pure (arrayConcat receiver other)
    [_] -> abortAt (Just spanValue) "E7001" "concat expects an array" Nothing
    _ -> wrongArity "concat" 1
  ArrayReverse -> case arguments of
    [] -> pure (arrayReverse receiver)
    _ -> wrongArity "reverse" 0
  ArrayMap -> case arguments of
    [closureValue] -> do
      elements <- case arrayToList receiver of
        Just values -> pure values
        Nothing -> abortAt (Just spanValue) "E7001" "not an array" Nothing
      results <- mapM (apply spanValue closureValue . (: [])) elements
      pure (arrayFromList results)
    _ -> wrongArity "map" 1
  ArrayFilter -> case arguments of
    [closureValue] -> do
      elements <- case arrayToList receiver of
        Just values -> pure values
        Nothing -> abortAt (Just spanValue) "E7001" "not an array" Nothing
      kept <- filterM (acceptByFunction apply spanValue closureValue) elements
      pure (arrayFromList kept)
    _ -> wrongArity "filter" 1
  ArrayReduce -> case arguments of
    [closureValue, initial] -> do
      elements <- case arrayToList receiver of
        Just values -> pure values
        Nothing -> abortAt (Just spanValue) "E7001" "not an array" Nothing
      foldM (\acc element -> apply spanValue closureValue [acc, element]) initial elements
    _ -> wrongArity "reduce" 2
 where
  wrongArity name expected =
    abortAt (Just spanValue) "E7003"
      (Text.pack (name <> " expects " <> show (expected :: Int) <> " argument(s)"))
      (Just "check the method's argument count")

{-| `panic` stops evaluation with `E7007`, taking the caller's message when one
    is supplied and a default otherwise, because a panic is a violated
    invariant rather than a recoverable domain failure. -}
callPanic :: Span -> [Value] -> Evaluator Value
callPanic spanValue values =
  case values of
    [StrValue message] -> abortAt (Just spanValue) "E7007" message Nothing
    _ -> abortAt (Just spanValue) "E7007" "panic" (Just "panic takes one string argument")

{-| The hashing the library cannot afford to write in the language.

    `Std.Crypto` still implements SHA-256 in Pudu, and that implementation is
    what shows the language can express the algorithm. These exist because a
    digest measured 23.6 ms there, and a database handshake derives a key with
    four thousand and ninety-six iterations of two digests: a minute of
    arithmetic to open one connection. A hash map's lookup cannot pay a digest
    either. Both answer the same digests, and the fixtures check them against
    each other rather than trusting that they do. -}
callHashing :: Span -> Builtin -> [Value] -> Evaluator Value
callHashing spanValue builtin arguments = case (builtin, arguments) of
  (Sha256Builtin, [BytesValue message]) -> pure (BytesValue (sha256 message))
  (HmacBuiltin, [BytesValue key, BytesValue message]) ->
    pure (BytesValue (hmacSha256 key message))
  (DeriveKeyBuiltin, [BytesValue password, BytesValue salt, IntValue _ rounds, IntValue _ wanted])
    | rounds < 1 -> refuse "an iteration count below one derives nothing"
    | rounds > 10000000 -> refuse "an iteration count above 10000000 is refused"
    | wanted < 1 -> refuse "a derived key of no length is not a key"
    | wanted > 1048576 -> refuse "a derived key above 1048576 bytes is refused"
    | otherwise ->
        pure
          ( BytesValue
              (pbkdf2Sha256 password salt (fromInteger rounds) (fromInteger wanted))
          )
  {-| Not a digest, and deliberately not offered as one. This is the mixing a
      hash map wants: cheap, well spread, and stable within a run. A value
      hashed with it is not hidden, and two runs are not promised the same
      number for the same value. -}
  (HashOfBuiltin, [value]) -> pure (intOf (hashOfValue value))
  {-| A hash spread across the whole word against a value chosen when the
      process started, so the bucket a key lands in cannot be predicted from
      the key alone. What a key equals is untouched. -}
  (MixHashBuiltin, [IntValue _ value]) -> pure (intOf (mixKey value))
  _ ->
    abortAt (Just spanValue) "E7012"
      ("wrong arguments for " <> builtinName builtin) Nothing
 where
  refuse message = abortAt (Just spanValue) "E7004" message Nothing
