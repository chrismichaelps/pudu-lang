{-| @Pudu.Backend.Emit.Range — the range type's aggregate helpers, thin calls
    into the range runtime, and the C for one range operation with the sites
    its failures report at. -}
module Pudu.Backend.Emit.Range (rangeHelpers, rangeMethodCall) where

import Data.Text (Text)
import qualified Data.Text as Text
import Pudu.Backend.Emit.Cell (aggregateHelper, aggregateNeed)
import Pudu.Backend.Emit.State (EmitState, helpedFailureSite, textOfInt)
import Pudu.Core (CoreRangeMethodName (..), CoreType)
import Pudu.Source (Span)

rangeHelpers :: CoreType -> [(Text, ([Text], [Text]))]
rangeHelpers kind =
  [ helper "drop" []
      [ "static void " <> name "drop" <> "(pudu_box *box) {"
      , "  if (box == NULL || --box->count != 0) return;"
      , "  free(box);"
      , "}" ]
  , helper "show" ["range_show"]
      [ "static pudu_text " <> name "show" <> "(pudu_box *box) {", "  return pudu_range_show(box);", "}" ]
  , helper "equal" ["range_equal"]
      [ "static int " <> name "equal" <> "(pudu_box *a, pudu_box *b) {", "  return pudu_range_equal(a, b);", "}" ]
  , helper "compare" ["range_compare"]
      [ "static int " <> name "compare" <> "(pudu_box *a, pudu_box *b) {", "  return pudu_range_compare(a, b);", "}" ]
  , helper "comparable" []
      [ "static int " <> name "comparable" <> "(pudu_box *box) {", "  (void)box;", "  return 1;", "}" ]
  ]
 where
  helper operation needs body = (aggregateNeed operation kind, (needs, body))
  name operation = aggregateHelper operation kind

{-| The call for one operation on `target` with `operands`, its runtime
    parts, and the state after its sites are added. -}
rangeMethodCall :: EmitState -> Span -> CoreRangeMethodName -> Text -> [Text] -> (EmitState, Text, [Text])
rangeMethodCall state at name target operands = case name of
  RangeLengthOf ->
    let (s1, unbounded) = helped state "E7004" "length needs a range with both ends" "check isBounded first, or give the range a start and an end"
        (s2, tooLong) = helped s1 "E7005" "Int cannot hold this range's length" bigInt
     in (s2, call "pudu_range_length" [site unbounded, site tooLong], ["range_length"])
  RangeIsEmptyOf -> (state, call "pudu_range_is_empty" [], ["range_is_empty"])
  RangeContainsValue -> (state, call "pudu_range_contains" [], ["range_contains"])
  RangeHasStart -> (state, field 0 "scalar", ["range"])
  RangeStartOf -> (state, field 1 "integer", ["range"])
  RangeHasEnd -> (state, field 3 "scalar", ["range"])
  RangeEndOf -> (state, field 4 "integer", ["range"])
  RangeIsInclusiveOf -> (state, field 2 "scalar", ["range"])
  RangeIsBoundedOf -> (state, "pudu_range_bounded(" <> target <> ")", ["range_bounded"])
  RangeValuesFor what ->
    let (after, unbounded) = needsEnds state what
     in (after, call "pudu_range_elements" [site unbounded], ["range_elements"])
  RangeIterated ->
    let (after, unbounded) = helped state "E7001" "cannot iterate a range"
          "implement Std.Iter.Sequence for it, which is begin and advance, or convert it to an array first"
     in (after, call "pudu_range_elements" [site unbounded], ["range_elements"])
  RangeReversedOf ->
    let (after, unbounded) = needsEnds state "reverse"
     in (after, call "pudu_range_reversed" [site unbounded], ["range_reversed"])
  RangeStepBy ->
    let (s1, notPositive) = helped state "E7004" "a step must be positive" "step by one or more; a range only ever counts upward"
        (s2, unbounded) = needsEnds s1 "step"
     in (s2, call "pudu_range_step" [site notPositive, site unbounded], ["range_step"])
  RangeSumOf ->
    let (s1, unbounded) = needsEnds state "sum"
        (s2, tooLarge) = helped s1 "E7005" "Int cannot hold this range's sum" bigInt
     in (s2, call "pudu_range_sum" [site unbounded, site tooLarge], ["range_sum"])
 where
  call function extra = function <> "(" <> Text.intercalate ", " (target : operands <> extra) <> ")"
  field position member = target <> "->fields[" <> textOfInt position <> "]." <> member
  site index = "&pudu_sites[" <> textOfInt index <> "]"
  helped current code message help = helpedFailureSite current at code message help
  needsEnds current what = helped current "E7004" (what <> " needs a range with both ends")
    "give the range a start and an end, or bound it against a value first"
  bigInt = "narrow the range or compute with BigInt values explicitly"
