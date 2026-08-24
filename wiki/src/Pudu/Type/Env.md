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

Own checker state, name frames, declared shapes, trait obligations, deferred integer-literal constraints, rigid bounds, and diagnostics for [[Type Check]].

## Interface

The exported signatures are the module header's export list.

### Governance

- Nominal types are equal by declaration identity and equal arguments; tuples, functions, and references are structural, matching [[architecture/SEMANTICS]].
- `Never` unifies with every type, which is the rule it is given for unreachable control-flow joins, and the error type absorbs so one mistake never cascades.
- An absent annotation becomes a fresh inference variable rather than a default, because defaulting would decide something the reader did not write.
- A type alias expands transparently; a declared generic parameter stays rigid inside the declaration that introduced it.
- Trait obligations are registered when a scheme is instantiated at a call site and discharged after the enclosing function's body is checked, while the parameter's own bounds are still in scope and inference has solved the argument types.
- `withRigidBounds` installs the enclosing declaration's parameter bounds so a generic body can call another generic that demands the same trait; a rigid parameter satisfies a bound its own declaration declared. Bounds from the parameter list and the `where` clause are merged with `(<>)` so a parameter carrying bounds in both places keeps all of them rather than the last entry overwriting the first.
- `implementsTrait` answers whether a nominal type has an implementation for a trait, read from `declaredImpls` which [[Type Formation]] collects from `impl` declarations.
- Declared shapes, implementation relationships, and method keys use canonical nominal/trait identity rather than basenames. Imported interface state is merged once before local signatures; local bindings remain in an inner frame.
- Imported concrete method keys are marked separately from ordinary name bindings. Local implementation installation can therefore diagnose an imported-plus-local provider collision without treating two local declarations as an import-order ambiguity or replacing coherence's duplicate-head diagnostic.
- Diagnostics use the `E3xxx` family and name the expected type first, because that is the one the reader declared. Coverage diagnostics use `E5xxx`, and a warning is available for rules that are advisory rather than prohibitive.
- Each integer literal receives a fresh variable plus its mathematical value and optional suffix-selected type. A type-variable creation frontier lets a semantic construct select only constraints created within its own walk or operand range. Validation checks solved constraints while retaining unresolved ones; forced finalization additionally defaults unresolved constraints to `Int`. Body finalization drains the remainder, and final products rewrite tooling types through the completed substitution.

### Linkage

- **Requires:** [[Type Value]], [[Type Interface]], [[Syntax Tree]], [[Diagnostic Model]].
- **Consumed by:** [[Type Check]], [[Type Check Rule]], [[Type Check Method]].

## Algorithm

Direct structural recursion over the type or syntax shape, with the checker's substitution consulted whenever a variable is reached. Obligations accumulate until body inference completes. Literal constraints are selected in source order by their creation frontier: solved constraints may be validated locally, a concrete-shape operand range may be forced, and the body boundary drains the remainder. Rigid bounds are saved and restored around each declaration's body. Final products recursively apply the completed substitution to recorded expression types.

## Negative Logic (Prohibited Paths)

- No subtyping beyond `Never`, no implicit numeric conversion, no general defaulting of unsolved variables, and no evaluation. The sole default is an unresolved unsuffixed integer literal to `Int`.
- No global mutable interface table and no dependency body in checker state.
- No method precedence by binding order: an imported provider marker survives until local signature installation decides whether the key is ambiguous.

## Edge Cases

- An occurs-check failure reports `E3002` rather than building a type that contains itself.
- An unsolved variable at discharge time proves nothing and is left alone rather than guessed at, because defaulting would decide something the reader did not write.
- A literal constrained to a non-integer type reports ordinary `E3001`; a literal outside a selected integer interval reports `E3018` once and becomes error poison for recorded tooling types.

## Depth

DEPTH 0.5 (MEDIUM). It keeps one concern out of [[Type Check]], which the delivery rules cap at 500 lines.

## Grill Log

- **Q:** Why a separate module? **A:** Because the checking walk is already deep, and formation, unification, and state are independently testable concerns. _Rationale:_ the split follows a real seam rather than a line count alone. _Rejected:_ one large checker file.
- **Q:** When are obligations discharged? **A:** After the function body, not at the call. _Rationale:_ the argument type may be an inference variable at call time and only solved later; discharging after the body checks what the reader wrote, not a guess. _Rejected:_ discharging at the call site; deferring to module end, which loses the enclosing scope's bounds.
- **Q:** Imported or local signatures first? **A:** Imported interface bindings form an outer checker frame; local signatures form the inner frame. _Rationale:_ resolution rejects illegal conflicts and local checking cannot overwrite a dependency interface silently. _Rejected:_ one biased `Map.union`.
- **Q:** Model an integer literal as `Int` immediately? **A:** No; retain a deferred literal constraint. _Rationale:_ annotations and call parameters must select narrower or wider integer types before fit checking, while a context-free literal still defaults predictably. _Rejected:_ hard-coded `Int`; caller-wide numeric promotion; a special nominal literal type that cannot record its later solution.
- **Q:** May a nested construct finalize every pending literal? **A:** No; it records the next type-variable identity and selects only constraints in the required creation range. Even within that range, branch/result validation retains unsolved constraints for an enclosing context. _Rationale:_ an annotated `if` or `match`, and an expression used beside another literal, must not default before its outer context is applied. _Rejected:_ global finalization at each diagnostic boundary; count-based stack slicing that nested settlement can invalidate; carrying unresolved shape diagnostics to module end.

## Referenced by

[[src/Pudu/Type/_MOC]] · [[Type Check]]
