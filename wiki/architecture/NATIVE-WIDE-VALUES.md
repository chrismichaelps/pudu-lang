---
type: architecture
aliases: [Native Wide Value Contract]
---
# Native Wide Value Contract

Store a wide integer as raw 128-bit bits and an independent actual-negative
flag. Positive deferred 2^127 must retain its sign. Make preserves requested
negative zero so later overflowing calculations can saturate toward the proper
bound; explicit normalization clears zero sign at value boundaries.

Magnitude uses modular negation for negative values. From-bits decodes the
selected signedness. Comparison normalizes zeros, compares signs first, then
raw words; two negative words have the same unsigned order as their values.
Limits return positive/negative magnitude bounds for signed/unsigned kinds.
Each helper declares its exact raw/wide dependency closure. Emit no headers,
allocation or global state. No source types, frame ABI or checked arithmetic
policies are admitted by this partition.

## Resolved Grill Log

- Actual sign is independent of the stored high bit.
- Preserve transient negative zero until mathematical normalization is safe.
- Compare negative zero equal to zero without changing construction semantics.
- Compile each single helper with strict C11 warnings and its prerequisites.

## Referenced by

[[architecture/_MOC]] · [[Backend Wide Integer Values]] · [[Native Wide Value Tests]]
