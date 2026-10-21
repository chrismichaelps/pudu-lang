---
type: module
path: "@root/src/Pudu/Type/Check/Subscript.hs"
fidelity: Active
domain: "[[Pudu Type]]"
subsystem: "[[Semantics]]"
grammar: "[[grammar/haskell]]"
tags: [module, semantics, indexing]
aliases: [Type Check Subscript]
---

# Type Check Subscript

## Purpose

Type `[]` on a type that is not built in, through its `index` and `setIndex` members (`Std.Index`), and refuse more than one index on a built-in type.

## Interface

```haskell
indexedByMember :: Type -> Bool
subscriptType :: Span -> Type -> [(Span, Type)] -> Checker Type
builtinMultiIndex :: Span -> Type -> Int -> Checker Type
subscriptWrite :: Span -> Type -> [(Span, Type)] -> Type -> Checker ()
subscriptAssignment :: Span -> Located Expression -> Located Expression -> [Located Expression] -> Checker ()
readThroughIndex :: Located Expression -> Checker Bool
copiedElement :: Span -> Checker Bool
```

- `indexedByMember` answers whether `[]` on a value of this type goes through the type's `index` member: a declared type or a type parameter, never a built-in.
- `subscriptType` types `value[i]` and `value[i, j, ...]`. It resolves `index`, unifies its receiver with `&target` and its key with the indices, records the key's shape by the expression's span, and answers `index`'s result. A key of `Array[I]` is the array of the indices, one index included, unless that one index is already an array. Otherwise one index is the key, and several are the tuple of them, which must have exactly that many members. An unsettled key becomes the tuple. A type without `index` is reported as not indexable, as a built-in that cannot be indexed is.
- `builtinMultiIndex` reports `E3094` for several indices on a string, array, tuple or other built-in, naming the chained form.
- `subscriptWrite` types `value[...] = item` through `setIndex`, unifying its receiver with `&mut target`, its key with the read's key, and its value with the item. A type without `setIndex` is `E3097`. `subscriptAssignment` reads the recorded types of an assignment's target, indices and element and calls it.
- `readThroughIndex` answers whether an expression reads through such an index, and `copiedElement` reports `E3096` for a write into, or a loan of, an element read that way. [[Type Check Place]] uses both.

## Invariants

- The shapes recorded here are the only input the rewrite in [[Compiler Literals]] uses to turn indexing on such a type into calls; built-in indexing records nothing and is evaluated as before.
- Indices are checked left to right before the key is formed; nothing here evaluates or reorders them.
- `E3095` reports a count of indices the key cannot hold.

## Grill Log

- **Q:** Define indexing through a new operator-overloading mechanism? **A:** No. A type joins `[]` the way a type joins `for`: by implementing a library trait whose members the syntax calls. The only special treatment is that the two traits are visible without an import ([[Type Interface Graph]]), because operator syntax cannot depend on one. _Rejected:_ an `operator[]` declaration form.
- **Q:** One key representation for several indices? **A:** Two. A tuple lets each position have its own type and fixes the count; an array serves a container whose rank is a run-time value, such as `Std.MdSpan`. The key's declared type chooses, so a call site never says which. _Rejected:_ always a tuple, which would leave a rank-generic view no way to accept `view[i, j, k]`.
- **Q:** With an `Array[I]` key, is `view[i]` the index or a one-element array? **A:** A one-element array, so a rank-generic container reads the same at every rank: `view[i]`, `view[i, j]`. A single index that is already an array is the key, so `view[position]` works for a computed position. _Rejected:_ requiring `view[[i]]` at rank one.
- **Q:** Should `a[i, j]` on an array mean `a[i][j]`? **A:** No; they are different operations and silently turning one into the other would hide a mistake. `E3094` names the chained form.
- **Q:** May a field of an element reached through `[]` be assigned? **A:** No. `index` returns a value, so the write would change a copy; `E3096` says to assign the whole element. Built-in arrays keep their element places.

## Dependencies and consumers

- **Requires:** [[Type Env]], [[Type Check Method]], [[Type Check Rule]], [[Type Unify]], [[Type Value]].
- **Consumed by:** [[Type Check Expression]], [[Type Check Place]].

## Referenced by

[[src/Pudu/Type/_MOC]] · [[Compiler Literals]]
