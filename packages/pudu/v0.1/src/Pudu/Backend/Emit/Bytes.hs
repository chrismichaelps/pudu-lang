{-| @Pudu.Backend.Emit.Bytes — the Bytes type's aggregate helpers and the
    runtime function behind each byte-sequence operation. -}
module Pudu.Backend.Emit.Bytes (bytesHelpers, bytesFunction) where

import Data.Text (Text)
import Pudu.Backend.Emit.Cell (aggregateHelper, aggregateNeed)
import Pudu.Core (CoreBytesMethodName (..), CoreType)

bytesHelpers :: CoreType -> [(Text, ([Text], [Text]))]
bytesHelpers kind =
  [ helper "drop" ["text"]
      [ "static void " <> name "drop" <> "(pudu_box *box) {"
      , "  if (box == NULL || --box->count != 0) return;"
      , "  pudu_text_release(box->fields[0].text);"
      , "  free(box);"
      , "}" ]
  , helper "show" ["bytes_show"]
      [ "static pudu_text " <> name "show" <> "(pudu_box *box) {", "  return pudu_bytes_show(box);", "}" ]
  , helper "equal" ["text_compare"]
      [ "static int " <> name "equal" <> "(pudu_box *a, pudu_box *b) {"
      , "  return pudu_text_compare(a->fields[0].text, b->fields[0].text) == 0;"
      , "}" ]
  , helper "compare" ["text_compare"]
      [ "/* Bytes order by their contents. */"
      , "static int " <> name "compare" <> "(pudu_box *a, pudu_box *b) {"
      , "  return pudu_text_compare(a->fields[0].text, b->fields[0].text);"
      , "}" ]
  , helper "comparable" []
      [ "static int " <> name "comparable" <> "(pudu_box *box) {", "  (void)box;", "  return 1;", "}" ]
  ]
 where
  helper operation needs body = (aggregateNeed operation kind, (needs, body))
  name operation = aggregateHelper operation kind

{-| The runtime function and its part. -}
bytesFunction :: CoreBytesMethodName -> (Text, Text)
bytesFunction name = case name of
  BytesOfArray -> ("pudu_bytes_pack", "bytes_pack")
  BytesFromText -> ("pudu_bytes_from_text", "bytes_from_text")
  BytesLengthOf -> ("pudu_bytes_length", "bytes_length")
  BytesAtIndex -> ("pudu_bytes_at", "bytes_at")
  BytesSliceOf -> ("pudu_bytes_slice", "bytes_slice")
  BytesTakeOf -> ("pudu_bytes_take", "bytes_take")
  BytesDropOf -> ("pudu_bytes_drop", "bytes_drop")
  BytesConcatWith -> ("pudu_bytes_concat", "bytes_concat")
  BytesIndexOfValue -> ("pudu_bytes_index_of", "bytes_index_of")
  BytesContainsValue -> ("pudu_bytes_contains", "bytes_contains")
  BytesStartsWithValue -> ("pudu_bytes_starts_with", "bytes_starts_with")
  BytesEndsWithValue -> ("pudu_bytes_ends_with", "bytes_ends_with")
  BytesReversed -> ("pudu_bytes_reverse", "bytes_reverse")
  BytesToArrayOf -> ("pudu_bytes_to_array", "bytes_to_array")
  BytesIsText -> ("pudu_bytes_is_text", "bytes_is_text")
  BytesAsText -> ("pudu_bytes_as_text", "bytes_as_text")
