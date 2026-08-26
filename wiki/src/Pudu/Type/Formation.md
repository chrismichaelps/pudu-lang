---
type: module
path: "@root/src/Pudu/Type/Formation.hs"
fidelity: Active
domain: "[[Pudu Type]]"
subsystem: "[[Semantics]]"
grammar: "[[grammar/haskell]]"
depth_score: 0.55
depth_status: MEDIUM
coupling: 2.0
interface_stability: 0.8
tags: [module, medium]
aliases: [Type Formation]
---

# Type Formation

## Purpose

Own type syntax to formed type, and what declarations contribute for [[Type Check]].

## Interface

The exported signatures are the module header's export list.

`collectDeclaredFrom` extends an imported declared environment before local collection; `collectDeclared` delegates from the empty environment.

### Governance

- A trait written where a type belongs is `E3030`, reported at the signature rather than at the first call that fails against the phantom type it used to form. Only a trait may follow `dynamic` (`E3031`); a dynamic type over one concrete type would be that type written the long way.
- Formation diagnostics report once per span and code. A signature is formed both when the module declares it and when its body is checked against it, and one mistake in one signature is one mistake.

- An alias is a **synonym**: writing it is writing what it stands for. A generic one substitutes its
  arguments, so `type Boxed[T] = Option[T]` used as `Boxed[Int]` *is* `Option[Int]`. Before this it
  was a nominal type of its own that unified with nothing, which made a type like
  `Parser[T] = fn(Input) -> Step[T]` impossible to use at all.
- An argument count that does not match the alias's parameters leaves the name nominal, so the
  mismatch is reported where the name was written rather than silently half-applied.
- The alias body is formed with its own parameters rigid, so they can be found and replaced; a rigid
  name from the surrounding declaration keeps its own meaning.

- `Decimal` is reserved: [[architecture/SEMANTICS]] gives it no semantics until its precision and rounding decision is accepted, so writing the type is refused with `E3022` rather than admitted with invented rounding. A module that declares its own `Decimal` keeps it, and each written occurrence reports once even though a signature is formed in two passes.

- Nominal types are equal by declaration identity and equal arguments; tuples, functions, and references are structural, matching [[architecture/SEMANTICS]].
- `Never` unifies with every type, which is the rule it is given for unreachable control-flow joins, and the error type absorbs so one mistake never cascades.
- An absent annotation becomes a fresh inference variable rather than a default, because defaulting would decide something the reader did not write.
- A type alias expands transparently; a declared generic parameter stays rigid inside the declaration that introduced it. The compiler wires in `Float` as an alias for `Float64`, because [[grammar/pudu]] makes the alias transparent at the type level and a reader who writes `Float` expects the same type as `Float64`.
- `DeclaredTypes` carries a path-to-canonical-identity map assembled by [[Type Interface]]. `formType` resolves the complete syntax path through that map before constructing `NominalType`; it never drops qualifiers to their last segment.
- Diagnostics use the `E3xxx` family and name the expected type first, because that is the one the reader declared.

- A variant written with field names carries the same positional payload as one written with types alone. The names are collected alongside the payload rather than instead of it, so nothing that reads a variant's shape needs to know which spelling declared it.

### Linkage

- **Requires:** [[Type Value]], [[Type Interface]], [[Syntax Tree]], [[Diagnostic Model]].
- **Consumed by:** [[Type Check]].

## Algorithm

Direct structural recursion over the type or syntax shape, with the checker's substitution consulted whenever a variable is reached.

## Negative Logic (Prohibited Paths)

- No subtyping beyond `Never`, no implicit numeric conversion, no trait resolution, no defaulting of unsolved variables, and no evaluation.
- No basename fallback for a path known to the loaded program. Isolated compilation retains explicit local and builtin mappings.

## Edge Cases

- An occurs-check failure reports `E3002` rather than building a type that contains itself.

## Depth

DEPTH 0.55 (MEDIUM). It keeps one concern out of [[Type Check]], which the delivery rules cap at 500 lines.

## Grill Log

- **Q:** Why keep the names at all, when the payload is positional either way? **A:** Because a construction and a pattern say which element they mean by naming it. _Rationale:_ the payload is what the type system needs and the names are what the reader needs; dropping them made `Circle{radius: 2}` compile to a positional constructor and then fail far from the declaration. _Rejected:_ discarding the names as the first version did.
- **Q:** Why a separate module? **A:** Because the checking walk is already deep, and formation, unification, and state are independently testable concerns. _Rationale:_ the split follows a real seam rather than a line count alone. _Rejected:_ one large checker file.
- **Q:** Where are import aliases interpreted? **A:** [[Type Interface]] produces canonical path bindings; formation only consumes them. _Rationale:_ import policy stays out of recursive type construction. _Rejected:_ inspecting `Import` syntax inside every `formType` call.

## Referenced by

[[src/Pudu/Type/_MOC]] · [[Type Check]]
