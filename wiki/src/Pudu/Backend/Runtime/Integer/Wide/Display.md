---
type: module
path: "@root/src/Pudu/Backend/Runtime/Integer/Wide/Display.hs"
fidelity: Active
aliases: [Backend Wide Integer Display]
grammar: "[[grammar/haskell]]"
---
# Backend Wide Integer Display

## Purpose and interface

Export wideDisplayRuntimeParts :: [(Text, [Text])] and
wideDisplayRuntimeDependencies :: Text -> [Text]. Implement wide_print_int and
wide_status per [[Native Wide Runtime Integration]], importing Data.Text only.

## Algorithm and invariants

Normalize zero before printing. Divide the exact magnitude by ten into a
41-byte reverse-filled buffer, adding optional sign/newline. Write once and
flush; no allocation or string termination is needed. Status checks both words
for zero/high magnitude before the bounded int conversion. Keep actual sign
separate from stored high bits. Select only precise raw/value prerequisites.

## Resolved Grill Log

- **Q:** Is 40 bytes enough with newline? **A:** No; reserve 41 for the largest sign/magnitude/newline.
- **Q:** Print a transient negative zero? **A:** No; explicit normalization renders zero canonically.
- **Q:** Depend on __int128 or signed overflow? **A:** No; use portable magnitude division and bounded status conversion.

## Dependencies and consumers

[[Backend Word128 Kernel]] · [[Backend Wide Integer Values]] · [[Backend Runtime Integer]] · [[Native Wide Runtime Tests]]

## Referenced by

[[src/_MOC]] · [[Backend Module Map]] · [[Native Wide Runtime Integration]]
