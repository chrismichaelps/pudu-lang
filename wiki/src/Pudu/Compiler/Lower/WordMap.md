---
type: module
path: "@root/src/Pudu/Compiler/Lower/WordMap.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
aliases: [Compiler Lower Word Map]
---
# Compiler Lower Word Map

Export lowerWordMapPrimitive, wordMapMethod and wordMapCallable for union,
intersection, difference and symmetric difference. Consume the checked result
or exact callable fact, requiring two identical Map[K, UInt64] arguments and
that same result. No key inference or integer-kind coercion.

## Resolved Grill Log

Lower arguments once in order, stopping on Never before visiting later ones.
Hold both operands in declaration order before CoreKeyedMethod: frame method
lowering reads arguments before its receiver, unlike a two-argument builtin.
Direct calls and callable bodies share this builder. Malformed facts refuse
at the call/reference. Native keys retain their existing canonical order.

## Referenced by

[[Compiler Lower Body]] · [[Compiler Lower Intrinsic]] · [[Core Keyed Operations]]
