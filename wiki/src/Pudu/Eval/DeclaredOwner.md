---
type: module
path: "@root/packages/pudu/v0.1/src/Pudu/Eval/DeclaredOwner.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
aliases: [Eval Declared Owner]
tags: [module, runtime, traits]
---
# Eval Declared Owner

Owns the method-key owner of a declared record or sum whose name a built-in value also answers to (`Array`, `Range`, `Str`, the integer and float kinds, and the rest `nominalNameOf` gives). Such a type's methods are installed under `@Name`, and its values, witnesses and qualified calls look there. A built-in value keeps the bare name, so neither ever runs a method written for the other (#529).

- `declaredOwner name` is `@name` for a built-in value name, and `name` otherwise.
- `declaredOwnerCandidates name` is the declared key, then the built-in one, for a written type name with no receiver to tell them apart (type witnesses, qualified calls with no arguments).

## Grill Log

- **Why a prefix and not the module-qualified name?** A record's runtime owner is its bare written name in the root module. A key no written name can spell (`@` cannot begin an identifier) separates the two families without touching record identity or the canonical sum owners.
- **Why only the built-in names?** Every other declared name already has no built-in counterpart, so its key stays as written, and nothing else in method installation changes.
- **Why its own module?** `Operator.Access`, `TypeWitness`, `Install`, `Loop` and `Call.Path` all use it. `TypeWitness` sits below `Operator.Access`, so the key has to live beneath both.

Backlinks: [[Eval Install]], [[Eval Loop]], [[Eval Type Witness]].
