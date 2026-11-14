---
type: module
path: "@root/src/Pudu/Backend/Runtime/Text/Methods.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
aliases: [Native Text Methods]
---
# Native Text Methods

## Purpose and interface

Export textMethodRuntimeParts and textMethodRuntimeDependencies. Every helper
borrows its text arguments; text results are new references, and drop, take
and slice return views that retain the receiver's owner.

| Part | C entry point | Evaluator source |
| --- | --- | --- |
| text_scalars | `pudu_text_scalars`, `pudu_text_advance`, `pudu_text_decode` | scalar walking |
| text_length / text_is_empty | `pudu_text_length`, `pudu_text_is_empty` | scalarCount, Text.null |
| text_find | `pudu_text_find` (first byte match) | Text.breakOn |
| text_contains / text_starts_with / text_ends_with | predicates | isInfixOf / isPrefixOf / isSuffixOf |
| text_index_of | `pudu_text_index_of` | indexOfText |
| text_drop / text_take / text_slice | views | dropText, Text.take, slice |
| text_repeat | `pudu_text_repeat` | Text.replicate with the size limit |
| text_reverse | `pudu_text_reverse` | Text.reverse |
| text_escape_html | `pudu_text_escape_html` | escapeHtmlText |
| text_replace | `pudu_text_replace` | Text.replace |
| text_span | `pudu_text_span(text, alphabet, accept)` | spanOf / spanNotOf |

Counts arrive as `pudu_int`; a negative count fails at its site before any
work, a count beyond the text clamps. The repeat limit is
`count * bytes > INT64_MAX`, the evaluator's `maxBound :: Int` on 64-bit
targets.

## Grill Log

- **Q:** Why byte search for Str needles? **A:** Valid UTF-8 never matches
  across a scalar boundary, so a byte match is a scalar match, as in Data.Text.
- **Q:** Why do views retain instead of copy? **A:** drop/take must cost what
  they move, as the grammar page promises for text scans.

## Referenced by

[[Native Text Runtime]] · [[Compiler Lower Text]] · [[src/_MOC]]

## Native byte views (#827)

Add granular byte-size/index-valid/byte-at/boundary/slice-valid/slice/find/find-last/scalar-at/scalar-width kernels. Arguments borrow text; slices retain existing owners through text_view. Reads require the lowering guard. Find kernels return pudu_int -1 for absence and otherwise exact byte offsets; use subtraction bounds before loops and retain overlapping matches. Empty needles and extreme signed magnitudes follow Eval.TextView. Reuse text_width and text_decode; no invalid UTF-8 or byte copies. See [[Native Text Views]].
