---
type: module
path: "@root/src/Pudu/Semantic/Prelude.hs"
fidelity: Active
domain: "[[Pudu Program]]"
subsystem: "[[Semantics]]"
grammar: "[[grammar/haskell]]"
depth_score: 0.3
depth_status: SHALLOW
coupling: 1.0
interface_stability: 1.0
tags: [module, shallow]
aliases: [Semantic Prelude]
---

# Semantic Prelude

## Purpose

Separate the types the compiler wires in from the names an implicitly imported prelude module supplies, so the prelude stays replaceable while the primitives stay inviolable.

## Interface

### Signatures

```haskell
wiredInTypeNames :: [Text]
preludeTypeNames :: [Text]
preludeValueNames :: [Text]
isPreludeModule :: ModuleName -> Bool
```

### Governance

- `Map` and `Set` are wired-in types and `mapOf`, `setOf`, and `charFromCode` are prelude values,
  because each is a construction or conversion nothing written in the language can express.

- Wired-in names are the grammar's builtin set plus the compiler-controlled `Copy` marker: sized signed and unsigned integers through 128 bits, target-width `Int`/`UInt`, `Float32`, `Float64`, the `Float` alias, `Bool`, `Char`, `Str`, `Never`, `BigInt`, `Decimal`, and the constructors `Option`, `Result`, `Array`, and `Task`. No module can remove them.
- The wired-in `Option` and `Result` carry their constructors — `Some`, `None`, `Ok`, `Err` — because a type the compiler provides is useless without the variants that build it. A module may declare its own `Ok`, which shadows the wired-in one.
- Prelude names are ordinary library declarations that happen to be imported implicitly: the traits and failure types [[architecture/SEMANTICS]] already names — `Drop`, `Send`, `Sync`, `Iterator`, `IntoIterator`, `From`, `Overflow`, `DivisionByZero` — and the value `panic`.
- The implicit import is suppressed by an explicit `import Core.Prelude`. A module that names the prelude therefore controls precisely what it takes.
- A module may declare its own `Drop` or `panic`; shadowing a prelude name is silent, because it displaces a library binding rather than a wired-in type or a user import.
- Library types such as `List` belong to neither list; a program that uses one imports it, which keeps the prelude from silently becoming a standard library.
- Names only. No arities, kinds, signatures, or definitions — those enter with typing, and a placeholder here would be a second source of truth.

### Linkage

- **Requires:** [[Syntax Name]], [[grammar/pudu]], [[architecture/SEMANTICS]].
- **Consumed by:** [[Name Resolution]].

## Algorithm

None; constant lists plus one module-name comparison.

## Negative Logic (Prohibited Paths)

- No implicit import of a user module, no operator definitions, no signatures, and no name that the normative vault does not already define.

## Edge Cases

- `Float` and `Float64` are separate names because the alias is transparent at the type level, not the name level.
- A module that imports the prelude and selects nothing takes nothing from it, which is the documented way to opt out.

## Depth

DEPTH 0.30 (SHALLOW by intent). It is a single normative list; deepening it before typing exists would invent structure the compiler cannot yet use.

## Grill Log

- **Q:** Should the prelude include `List`, `Map`, or `print`? **A:** No. _Rationale:_ [[grammar/pudu]] enumerates the builtins and [[architecture/SEMANTICS]] names the rest; inventing convenience bindings here would create a standard library nobody specified. _Rejected:_ a convenience prelude; ambient value bindings.
- **Q:** Are wired-in and prelude names one list or two? **A:** Two, in separate scope layers. _Rationale:_ splitting wired-in types from the prelude module is what makes the prelude replaceable while keeping primitives inviolable, and Pudu wants both properties. _Rejected:_ one flat builtin list, which would make `Int` shadowable and `Drop` unremovable — precisely backwards.
- **Q:** How is the implicit import disabled? **A:** By importing the prelude explicitly. _Rationale:_ it reuses syntax the language already has instead of adding a pragma or compiler flag. _Rejected:_ a `NoImplicitPrelude`-style flag before the language has any flags.

## Referenced by

[[src/Pudu/Semantic/_MOC]] · [[Name Resolution]] · [[grammar/pudu]]
