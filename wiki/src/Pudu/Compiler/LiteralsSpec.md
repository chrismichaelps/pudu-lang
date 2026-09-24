---
type: module
path: "@root/test/Pudu/Compiler/LiteralsSpec.hs"
fidelity: Active
domain: "[[Compiler Pipeline]]"
subsystem: "[[Backend]]"
grammar: "[[grammar/haskell]]"
tags: [module, test, performance, lowering]
aliases: [Compiler Literals Spec]
---
# Compiler Literals Spec

Compiles one module through `runCompile` and reads both trees. In `compileModule`, `0xFF` is
`ResolvedInteger PlatformSigned 255`, and the `1` in `x + 1` and the `2` passed as an argument are
`ResolvedInteger (UnsignedKind 8)`, the kind checking gave them from `UInt8`; no `IntegerValue` text
remains. In `compileSyntax` the same literals keep their source text, in order.

The product cache's own property ([[Cache Persist]]) now includes an unbounded integer read back
digit for digit, since a stored module carries resolved values.

See [[Compiler Literals]].

## Grill Log

Resolved Grill Log: the kind is asserted where the checker chose it rather than the default, because
that is the case a wrong resolution would get wrong silently.
