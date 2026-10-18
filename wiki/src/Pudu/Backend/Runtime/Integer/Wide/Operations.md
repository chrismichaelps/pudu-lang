---
type: module
path: "@root/src/Pudu/Backend/Runtime/Integer/Wide/Operations.hs"
fidelity: Planned
aliases: [Backend Wide Operations]
grammar: "[[grammar/haskell]]"
---
# Backend Wide Operations

## Purpose and interface

Export wideOperationRuntimeParts :: [(Text, [Text])] and
wideOperationRuntimeDependencies :: Text -> [Text], pure C11 arithmetic,
bitwise and checked shift catalogues for [[Native Wide Operations]].
Use Data.Text only; no evaluator/frontend or external dependency.

## Algorithm and invariants

Expose wide_add_math/multiply_math and checked/saturate_result policy helpers;
wide_add/sub/mul/div/rem/neg, sat_add/sub/mul, wrap_add/sub/mul,
bit_and/or/xor/not, shift_left/right. All C function names have pudu_ prefix.
Use raw unsigned words and exact actual sign. Carry survives until the result
policy; zero normalization must not discard saturation direction. Count type
is existing pudu_int. Dependencies include every raw/value/site/fail/count
prerequisite. No heap, source admission or frame ABI change in this module.

## Resolved Grill Log

- **Q:** Use host signed overflow or __int128? **A:** No; only the portable word kernel.
- **Q:** A zero low product proves no overflow? **A:** No; preserve the kernel's upper-product flag.
- **Q:** Conflate zero-divisor and overflow sites? **A:** No; route each supplied site precisely.
- **Q:** Ignore count zero and word-crossing boundaries? **A:** No; total raw helpers plus checked counts handle them explicitly.

## Dependencies and consumers

[[Backend Word128 Kernel]] · [[Backend Wide Integer Values]] · [[Native Wide Operation Tests]]

## Referenced by

[[src/_MOC]] · [[Backend Module Map]] · [[Native Wide Operations]]
