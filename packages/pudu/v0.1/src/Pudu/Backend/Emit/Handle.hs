{-| @Backend.Emit.Handle — the aggregate helpers of a foreign handle type. A
    handle is a box of two cells: the address the library handed back, then
    the claim it holds (zero when borrowed). Releasing the box frees only the
    box; the library's object is released by its release function or when
    the program ends. -}
module Pudu.Backend.Emit.Handle (handleHelpers) where

import Data.Text (Text)
import Pudu.Backend.Emit.Cell (aggregateHelper, aggregateNeed)
import Pudu.Backend.Emit.State (cString, cStringBytes, textOfInt)
import Pudu.Core (CoreType)

{-| Drop, show, name, equality and the evaluator's same-shape order. Two
    handles are equal when they hold the same address under the same claim,
    as the interpreter compares them. -}
handleHelpers :: CoreType -> Text -> [(Text, ([Text], [Text]))]
handleHelpers kind name =
  [ helper "drop" []
      [ "static void " <> named "drop" <> "(pudu_box *box) {"
      , "  if (box == NULL || --box->count != 0) return;"
      , "  free(box);"
      , "}" ]
  , helper "show" ["text_concat", "text_literal"]
      [ "static pudu_text " <> named "show" <> "(pudu_box *box) {"
      , "  char address[17];"
      , "  int length = snprintf(address, sizeof address, \"%\" PRIx64, box->fields[0].floating);"
      , "  return pudu_text_concat(pudu_text_literal(" <> cString prefix <> ", " <> textOfInt (cStringBytes prefix) <> "),"
      , "    pudu_text_literal(address, length < 0 ? 0 : (size_t)length));"
      , "}" ]
  , helper "name" ["text_literal"]
      [ "static pudu_text " <> named "name" <> "(pudu_box *box) {"
      , "  (void)box;"
      , "  return pudu_text_literal(" <> cString name <> ", " <> textOfInt (cStringBytes name) <> ");"
      , "}" ]
  , helper "equal" []
      [ "static int " <> named "equal" <> "(pudu_box *a, pudu_box *b) {"
      , "  return a->fields[0].floating == b->fields[0].floating && a->fields[1].floating == b->fields[1].floating;"
      , "}" ]
  , helper "comparable" []
      [ "static int " <> named "comparable" <> "(pudu_box *box) {", "  (void)box;", "  return 1;", "}" ]
  , helper "compare" []
      [ "static int " <> named "compare" <> "(pudu_box *a, pudu_box *b) {", "  (void)a; (void)b;", "  return 0;", "}" ]
  ]
 where
  prefix = "<" <> name <> " at 0x"
  helper operation needs body = (aggregateNeed operation kind, (needs, body))
  named operation = aggregateHelper operation kind
