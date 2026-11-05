---
type: module
path: "@root/src/Pudu/Compiler/Lower/WordMap.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
aliases: [Compiler Lower Word Map]
---
# Compiler Lower Word Map

Export lowerWordMapPrimitive, wordMapMethod and wordMapCallable for union,
intersection, difference, symmetric difference, subset, disjointness, count and members. Consume exact checked result or callable facts, requiring UInt64-valued maps and the operation-specific result/arity. No key inference or integer-kind coercion.

## Resolved Grill Log

Lower arguments once in order, stopping on Never before visiting later ones.
Hold both operands in declaration order before CoreKeyedMethod: frame method
lowering reads arguments before its receiver, unlike a two-argument builtin.
Direct calls and callable bodies share this builder. Malformed facts refuse
at the call/reference. Native keys retain their existing canonical order.

## Referenced by

[[Compiler Lower Body]] · [[Compiler Lower Intrinsic]] · [[Core Keyed Operations]]

## Query contract (#814)

Admit all eight sparse-word primitives from exact checked argument/result facts. Lower operands once in source order and stop on Never before visiting later operands; snapshot surviving operands before keyed frame lowering. Unary count/members and binary predicate/algebra values reuse one signature validator and builder. Preserve the four existing algebra signatures.

Resolved Grill Log: project existing checked semantics; no inference, fallback, unsafe cell reinterpretation or frame ABI change. Reuse granular runtime dependencies and existing numeric/array ownership kernels.
