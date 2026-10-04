---
type: module
path: "@root/packages/pudu/v0.1/src/Pudu/Type/Formation/Builtin.hs"
fidelity: Active
domain: "[[Pudu Type]]"
subsystem: "[[Semantics]]"
grammar: "[[grammar/haskell]]"
tags: [module, formation]
aliases: [Type Formation Builtins]
---

# Type Formation Builtins

## Purpose and interface

Own the fixed language type inventory, constructor parameter arities, Option and
Result variant facts and the transparent Float alias. Export builtinTypeNames,
builtinKinds, builtinVariants, builtinOwnedVariants, builtinOwners and builtinAliases.

## Algorithm

Pure closed maps project names, arities, owned variants and carrier payloads.
Ownerless identities distinguish language types from same-named user declarations.
User constructor kinds belong to declaration shells and take precedence in
[[Type Check Bound]]. Formation imports this inventory without rebuilding it.

## Edge cases and negative logic

No signature/body checking, inference, source traversal, diagnostics or IO.
No guess based on a qualified nominal's final segment. Byte/string types have
arity zero, Array/Set/Option/Range/Buckets one and Map/Result/Task two. Only
Option and Result have wired-in sum constructors; extracting these maps does
not add constructors or alter alias semantics.

## Grill Log

- **Q:** Duplicate the language constructor arities in bound validation?
  **A:** No; keep the closed inventory beside the wired-in formation facts.
  _Rationale:_ built-in names and shapes are one responsibility, distinct from
  recursive source formation. _Rejected:_ expanding Formation beyond its file
  limit or dispatching by a user type's basename.

## Referenced by

[[Type Formation]] · [[Type Check Bound]] · [[src/Pudu/Type/_MOC]]
