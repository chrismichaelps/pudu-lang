---
type: module
path: "@root/packages/pudu/v0.1/src/Pudu/Backend/Runtime/Integer/Wide/Value.hs"
fidelity: Active
aliases: [Backend Wide Integer Values]
---
# Backend Wide Integer Values

Export wideValueRuntimeParts and wideValueRuntimeDependencies, ordered pure
C11 fragments and their exact dependency edges. Data.Text is the sole import.
Define pudu_wide_int (bits/negative), pudu_wide_kind (is_signed), and
pudu_wide_calculation (value/overflow). Supply magnitude, make, normal,
from_bits, compare and limit helpers under [[Native Wide Value Contract]].
Unknown names have no dependencies. Types precede consumers.

## Resolved Grill Log

- Positive 2^127 retains its independent actual sign.
- Make retains negative zero; normal clears it explicitly.
- Comparison normalizes zeros and checks signs before unsigned words.
- Minimal dependency selection must compile warning-free, without attributes.

## Dependencies and consumers

[[Backend Word128 Kernel]] · [[Native Wide Value Tests]] · [[Pudu Cabal Manifest]]

## Referenced by

[[src/_MOC]] · [[Native Wide Value Contract]] · [[Native Wide Value Publication]]
