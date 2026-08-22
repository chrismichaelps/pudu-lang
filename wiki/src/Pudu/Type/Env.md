---
type: module
path: "@root/src/Pudu/Type/Env.hs"
fidelity: Active
domain: "[[Pudu Type]]"
subsystem: "[[Semantics]]"
grammar: "[[grammar/haskell]]"
depth_score: 0.5
depth_status: MEDIUM
coupling: 2.0
interface_stability: 0.8
tags: [module, medium]
aliases: [Type Env]
---

# Type Env

## Purpose

Own checker state, name frames, declared shapes, trait obligations, rigid bounds, and diagnostics for [[Type Check]].

## Interface

The exported signatures are the module header's export list.

### Governance

- Nominal types are equal by declaration identity and equal arguments; tuples, functions, and references are structural, matching [[architecture/SEMANTICS]].
- `Never` unifies with every type, which is the rule it is given for unreachable control-flow joins, and the error type absorbs so one mistake never cascades.
- An absent annotation becomes a fresh inference variable rather than a default, because defaulting would decide something the reader did not write.
- A type alias expands transparently; a declared generic parameter stays rigid inside the declaration that introduced it.
- Trait obligations are registered when a scheme is instantiated at a call site and discharged after the enclosing function's body is checked, while the parameter's own bounds are still in scope and inference has solved the argument types.
- `withRigidBounds` installs the enclosing declaration's parameter bounds so a generic body can call another generic that demands the same trait; a rigid parameter satisfies a bound its own declaration declared.
- `implementsTrait` answers whether a nominal type has an implementation for a trait, read from `declaredImpls` which [[Type Formation]] collects from `impl` declarations.
- Diagnostics use the `E3xxx` family and name the expected type first, because that is the one the reader declared. Coverage diagnostics use `E5xxx`, and a warning is available for rules that are advisory rather than prohibitive.

### Linkage

- **Requires:** [[Type Value]], [[Syntax Tree]], [[Diagnostic Model]].
- **Consumed by:** [[Type Check]], [[Type Check Rule]], [[Type Check Method]].

## Algorithm

Direct structural recursion over the type or syntax shape, with the checker's substitution consulted whenever a variable is reached. Obligations accumulate in a list and are taken out in reverse order at discharge time; rigid bounds are a map saved and restored around each declaration's body.

## Negative Logic (Prohibited Paths)

- No subtyping beyond `Never`, no implicit numeric conversion, no defaulting of unsolved variables, and no evaluation.

## Edge Cases

- An occurs-check failure reports `E3002` rather than building a type that contains itself.
- An unsolved variable at discharge time proves nothing and is left alone rather than guessed at, because defaulting would decide something the reader did not write.

## Depth

DEPTH 0.5 (MEDIUM). It keeps one concern out of [[Type Check]], which the delivery rules cap at 500 lines.

## Grill Log

- **Q:** Why a separate module? **A:** Because the checking walk is already deep, and formation, unification, and state are independently testable concerns. _Rationale:_ the split follows a real seam rather than a line count alone. _Rejected:_ one large checker file.
- **Q:** When are obligations discharged? **A:** After the function body, not at the call. _Rationale:_ the argument type may be an inference variable at call time and only solved later; discharging after the body checks what the reader wrote, not a guess. _Rejected:_ discharging at the call site; deferring to module end, which loses the enclosing scope's bounds.

## Referenced by

[[src/Pudu/Type/_MOC]] · [[Type Check]]
