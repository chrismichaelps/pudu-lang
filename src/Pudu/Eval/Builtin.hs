{-| @Program.Eval.Builtin — implements the values the prelude wires in -}
module Pudu.Eval.Builtin
  ( Apply
  , callArrayMethod
  , callCharFromCode
  , callCharMethod
  , callConvertInteger
  , callDecimal
  , callDisplay
  , callEffect
  , callHashing
  , callMapMethod
  , callMapOf
  , callPanic
  , callSetMethod
  , callSetOf
  , callShow
  , callStringMethod
  , effectBuiltins
  , isDecimalBuiltin
  , isHashingBuiltin
  ) where

import qualified Data.Text as Text

import qualified Pudu.Eval.Buffer as Buffer
import qualified Pudu.Eval.Column as Column
import qualified Pudu.Eval.SwissTable as Swiss
import qualified Pudu.Runtime.Word as Word

import Pudu.Eval.Builtin.Array (Apply, callArrayMethod)
import Pudu.Eval.Builtin.Collection
  ( callMapMethod
  , callMapOf
  , callSetMethod
  , callSetOf
  )
import Pudu.Eval.Builtin.Numeric
  ( callCharFromCode
  , callCharMethod
  , callConvertInteger
  , callDecimal
  , isDecimalBuiltin
  )
import Pudu.Eval.Builtin.String (callStringMethod)
import Pudu.Eval.Effect (callEffect, effectBuiltins)
import Pudu.Eval.Env (Evaluator (..), abortAt)
import Pudu.Eval.Hash (hashOfValue, hmacSha256, pbkdf2Sha256, sha256)
import Pudu.Eval.HashMap (mixKey)
import Pudu.Eval.Render (renderValue)
import Pudu.Eval.Value
  ( Builtin (..)
  , Value (..)
  , builtinName
  , intOf
  )
import Pudu.Eval.WordMap
  ( callWordMapAlgebra
  , callWordMapMembers
  , callWordMapPopCount
  , callWordMapPredicate
  )
import Pudu.Source (Span)

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
  (WordMapUnionBuiltin, values) -> callWordMapAlgebra spanValue "wordMapUnion" Word.WordUnion values
  (WordMapIntersectionBuiltin, values) -> callWordMapAlgebra spanValue "wordMapIntersection" Word.WordIntersection values
  (WordMapDifferenceBuiltin, values) -> callWordMapAlgebra spanValue "wordMapDifference" Word.WordDifference values
  (WordMapSymmetricDifferenceBuiltin, values) -> callWordMapAlgebra spanValue "wordMapSymmetricDifference" Word.WordSymmetricDifference values
  (WordMapIsSubsetOfBuiltin, values) -> callWordMapPredicate spanValue "wordMapIsSubsetOf" Word.WordSubset values
  (WordMapIsDisjointFromBuiltin, values) -> callWordMapPredicate spanValue "wordMapIsDisjointFrom" Word.WordDisjoint values
  (WordMapPopCountBuiltin, values) -> callWordMapPopCount spanValue values
  (WordMapMembersBuiltin, values) -> callWordMapMembers spanValue values
  (HashOfBuiltin, [value]) -> pure (intOf (hashOfValue value))
  (MixHashBuiltin, [IntValue _ value]) -> pure (intOf (mixKey value))
  (BufferAllocBuiltin, values) -> Buffer.callBufferAlloc spanValue values
  (BufferReadU64Builtin, values) -> Buffer.callBufferReadU64 spanValue values
  (BufferWriteU64Builtin, values) -> Buffer.callBufferWriteU64 spanValue values
  (BufferReadI64Builtin, values) -> Buffer.callBufferReadI64 spanValue values
  (BufferWriteI64Builtin, values) -> Buffer.callBufferWriteI64 spanValue values
  (BufferReadF64Builtin, values) -> Buffer.callBufferReadF64 spanValue values
  (BufferWriteF64Builtin, values) -> Buffer.callBufferWriteF64 spanValue values
  (BufferReadU32Builtin, values) -> Buffer.callBufferReadU32 spanValue values
  (BufferWriteU32Builtin, values) -> Buffer.callBufferWriteU32 spanValue values
  (BufferFillBuiltin, values) -> Buffer.callBufferFill spanValue values
  (BufferCompareBuiltin, values) -> Buffer.callBufferCompare spanValue values
  (BufferScanU64Builtin, values) -> Buffer.callBufferScanU64 spanValue values
  (BufferCopyBuiltin, values) -> Buffer.callBufferCopy spanValue values
  (BufferSizeBuiltin, values) -> Buffer.callBufferSize spanValue values
  (SwissTableEmptyBuiltin, values) -> Swiss.callSwissTableEmpty spanValue values
  (SwissTableLookupBuiltin, values) -> Swiss.callSwissTableLookup spanValue values
  (SwissTableInsertBuiltin, values) -> Swiss.callSwissTableInsert spanValue values
  (SwissTableDeleteBuiltin, values) -> Swiss.callSwissTableDelete spanValue values
  (SwissTableEntriesBuiltin, values) -> Swiss.callSwissTableEntries spanValue values
  (SwissTableSizeBuiltin, values) -> Swiss.callSwissTableSize spanValue values
  (ColumnSumU64Builtin, values) -> Column.callColumnSumU64 spanValue values
  (ColumnMinU64Builtin, values) -> Column.callColumnMinU64 spanValue values
  (ColumnMaxU64Builtin, values) -> Column.callColumnMaxU64 spanValue values
  (ColumnFilterGtU64Builtin, values) -> Column.callColumnFilterGtU64 spanValue values
  (ColumnProjectU64Builtin, values) -> Column.callColumnProjectU64 spanValue values
  (ColumnSumF64Builtin, values) -> Column.callColumnSumF64 spanValue values
  (ColumnMinF64Builtin, values) -> Column.callColumnMinF64 spanValue values
  (ColumnMaxF64Builtin, values) -> Column.callColumnMaxF64 spanValue values
  (ColumnFilterGtF64Builtin, values) -> Column.callColumnFilterGtF64 spanValue values
  (ColumnFilterLtF64Builtin, values) -> Column.callColumnFilterLtF64 spanValue values
  (ColumnProjectF64Builtin, values) -> Column.callColumnProjectF64 spanValue values
  (ColumnAddF64Builtin, values) -> Column.callColumnAddF64 spanValue values
  (ColumnBitmapAndBuiltin, values) -> Column.callColumnBitmapAnd spanValue values
  (ColumnBitmapOrBuiltin, values) -> Column.callColumnBitmapOr spanValue values
  (ColumnBitmapNotBuiltin, values) -> Column.callColumnBitmapNot spanValue values
  (ColumnBitmapCountBuiltin, values) -> Column.callColumnBitmapCount spanValue values
  (ColumnSortIndicesU64Builtin, values) -> Column.callColumnSortIndicesU64 spanValue values
  (ColumnSortIndicesF64Builtin, values) -> Column.callColumnSortIndicesF64 spanValue values
  (ColumnBinarySearchU64Builtin, values) -> Column.callColumnBinarySearchU64 spanValue values
  (ColumnBinarySearchF64Builtin, values) -> Column.callColumnBinarySearchF64 spanValue values
  (ColumnGatherU64Builtin, values) -> Column.callColumnGatherU64 spanValue values
  (ColumnGatherF64Builtin, values) -> Column.callColumnGatherF64 spanValue values
  _ ->
    abortAt (Just spanValue) "E7012"
      ("wrong arguments for " <> builtinName builtin) Nothing
 where
  refuse message = abortAt (Just spanValue) "E7004" message Nothing

{-| Whether a built-in is one of the hashing set, which is dispatched before
    the effects because none of them reaches outside the program: a digest of
    the same bytes is the same digest wherever it is taken, so a constant may
    be folded through one. -}
isHashingBuiltin :: Builtin -> Bool
isHashingBuiltin builtin = case builtin of
  Sha256Builtin -> True
  HmacBuiltin -> True
  DeriveKeyBuiltin -> True
  WordMapUnionBuiltin -> True
  WordMapIntersectionBuiltin -> True
  WordMapDifferenceBuiltin -> True
  WordMapSymmetricDifferenceBuiltin -> True
  WordMapIsSubsetOfBuiltin -> True
  WordMapIsDisjointFromBuiltin -> True
  WordMapPopCountBuiltin -> True
  WordMapMembersBuiltin -> True
  HashOfBuiltin -> True
  MixHashBuiltin -> True
  BufferAllocBuiltin -> True
  BufferReadU64Builtin -> True
  BufferWriteU64Builtin -> True
  BufferScanU64Builtin -> True
  BufferCopyBuiltin -> True
  BufferSizeBuiltin -> True
  SwissTableEmptyBuiltin -> True
  SwissTableLookupBuiltin -> True
  SwissTableInsertBuiltin -> True
  SwissTableDeleteBuiltin -> True
  SwissTableEntriesBuiltin -> True
  SwissTableSizeBuiltin -> True
  BufferReadI64Builtin -> True
  BufferWriteI64Builtin -> True
  BufferReadF64Builtin -> True
  BufferWriteF64Builtin -> True
  BufferReadU32Builtin -> True
  BufferWriteU32Builtin -> True
  BufferFillBuiltin -> True
  BufferCompareBuiltin -> True
  ColumnSumU64Builtin -> True
  ColumnMinU64Builtin -> True
  ColumnMaxU64Builtin -> True
  ColumnFilterGtU64Builtin -> True
  ColumnProjectU64Builtin -> True
  ColumnSumF64Builtin -> True
  ColumnMinF64Builtin -> True
  ColumnMaxF64Builtin -> True
  ColumnFilterGtF64Builtin -> True
  ColumnFilterLtF64Builtin -> True
  ColumnProjectF64Builtin -> True
  ColumnAddF64Builtin -> True
  ColumnBitmapAndBuiltin -> True
  ColumnBitmapOrBuiltin -> True
  ColumnBitmapNotBuiltin -> True
  ColumnBitmapCountBuiltin -> True
  ColumnSortIndicesU64Builtin -> True
  ColumnSortIndicesF64Builtin -> True
  ColumnBinarySearchU64Builtin -> True
  ColumnBinarySearchF64Builtin -> True
  ColumnGatherU64Builtin -> True
  ColumnGatherF64Builtin -> True
  _ -> False

