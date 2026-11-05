---
type: module
path: "@root/test/Pudu/Backend/WordMapPrograms.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
aliases: [Backend Word Map Programs]
---
# Backend Word Map Programs

Export wordMapSuccessPrograms and wordMapRefusalPrograms. Cover all eight
operations on overlapping/disjoint/empty inputs, zero omission, high/all-bit
words, immutable inputs, owned keys and float representatives. Exercise
direct calls, explicit type applications, aliases/captures, builtin identity,
argument order/transfers and exact runtime failure provenance.

## Resolved Grill Log

Use independent handwritten output and the existing differential and counted
allocation harnesses. Focused groups supplement the ordinary module corpora.
Other accelerated families remain separate obligations.

## Referenced by

[[Backend Native Tests]] · [[Backend Text Leak Tests]] · [[Backend Module Programs]]

## Query contract (#814)

Cover all four queries with independent answers, empty/zero/high/all-bit words, owned/aggregate/NaN keys, binary snapshots, direct/value/captured calls and transfers. Pin UInt128 count arithmetic and chunk-wrap duplicate member IDs. Exercise unary/binary argument failures and each builtin as an entry. Existing complete module and counted-cleanup corpora include these cases.

Resolved Grill Log: project existing checked semantics; no inference, fallback, unsafe cell reinterpretation or frame ABI change. Reuse granular runtime dependencies and existing numeric/array ownership kernels.

The count is consumed by UInt128 arithmetic carrying across 2^64. Both direct and first-class transfers stop later operand effects; both unary query families retain argument-failure provenance. Standalone entries pin granular runtime selection without suppressing native compiler warnings.
