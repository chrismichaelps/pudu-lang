---
type: module
path: "@root/src/Pudu/Backend/Runtime/Integer/Wide/Value.hs"
fidelity: Active
aliases: [Backend Wide Integer Values]
grammar: "[[grammar/haskell]]"
---
# Backend Wide Integer Values

## Purpose and interface

Export wideValueRuntimeParts :: [(Text, [Text])] and
wideValueRuntimeDependencies :: Text -> [Text], pure ordered C11 fragments
for [[Native Wide Integers]]. Import Data.Text only; no frontend or new dependency.

## Algorithm and invariants

Define pudu_wide_int bits/actual sign, pudu_wide_kind signedness, and
pudu_wide_calculation value/overflow. Provide wide_magnitude, wide_make,
wide_normal, wide_from_bits, wide_compare and wide_limit. Retain requested
negative zero from make until explicit normalization, preserving overflow
saturation direction. Compare canonicalizes zeros, tests signs first, then
compares raw words. Return signed positive/negative magnitude limits or
unsigned maximum/zero. Select precise raw helper prerequisites; define types
before consumers. No ABI change to existing frames and no source admission.

## Resolved Grill Log

- **Q:** Treat positive 2^127 as negative? **A:** No; actual sign is independent of stored high bits.
- **Q:** Clear sign from an overflowing zero magnitude? **A:** No; make preserves it, normal clears it at a value boundary.
- **Q:** Order negative zero before zero? **A:** No; comparison normalizes zero first.
- **Q:** Embed all raw helpers? **A:** No; explicit dependencies support warning-free minimal selections.

## Dependencies and consumers

[[Backend Word128 Kernel]] · [[Native Wide Value Tests]] · [[Pudu Cabal Manifest]]

## Referenced by

[[src/_MOC]] · [[Backend Module Map]] · [[Native Wide Integers]]
