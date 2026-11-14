---
type: module
path: "@root/src/Pudu/Compiler/Lower/Store.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
aliases: [Compiler Lower Store]
---
# Compiler Lower Store

Export lowerStorePrimitive and storeCallable. `lowerStorePrimitive` answers
direct calls of `bucketsOf`, `hashOf`, `mixHash`, `multiMapAdd` and
`multiMapContains`;
`storeCallable` gives the same bodies over a callable's parameters for a
solved signature. Store methods themselves are in [[Compiler Lower Keyed]].

`bucketsOf()` requires a solved `CoreStoreType` result and no arguments.
`mixHash` requires one Int operand and an Int result. `hashOf` takes any
native value and answers Int: text, bytes and integers hash by their own
bytes, anything else by the text `show` gives it; a `Result[(), Str]` print
value refuses. The MultiMap pair is
delegated to [[Compiler Lower Multi Map]].

## Resolved Grill Log

Lower operands once in source order, stopping on Never before later ones.
Admit only exact checked signatures; anything else refuses at the call or
reference. Direct calls and callable bodies share one builder per primitive,
so they cannot drift. No inference and no fallback to another collection.

## Referenced by

[[Compiler Lower Body]] · [[Compiler Lower Intrinsic]] · [[Native Indexed Stores]]
