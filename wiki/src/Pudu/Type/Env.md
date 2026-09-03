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
- A loop frame records the loop's label, the type it produces, and whether it may carry a value out at all. `loop` produces what its `break` statements carry, so every `break` leaving one unifies against the same result variable; `while` and `for` can finish on their own condition without reaching a `break`, so a value carried out of one would exist on some runs and not others, and `E3029` says so rather than inventing a default. A `loop` no `break` leaves is `Never`.
- `withoutLoops` clears the loop stack for a function body, mirroring [[Resolve Context]]: a closure defined in a loop is not inside it.
- Diagnostics use the `E3xxx` family and name the expected type first, because that is the one the reader declared. Coverage diagnostics use `E5xxx`, and a warning is available for rules that are advisory rather than prohibitive.
- Each integer literal receives a fresh variable plus its mathematical value and optional suffix-selected type. A type-variable creation frontier lets a semantic construct select only constraints created within its own walk or operand range. Validation checks solved constraints while retaining unresolved ones; forced finalization additionally defaults unresolved constraints to `Int`. Body finalization drains the remainder, and final products rewrite tooling types through the completed substitution.

- **A variant's declared field names are held apart from its payload types.** A variant is present in `declaredVariantFields` only when its declaration gave names; one that gave none is absent rather than present and empty, because writing `Circle{}` for a positional variant is a different mistake from leaving a field out.

- **What inference settled on for each integer literal is published, keyed by its whole span.** A literal written without a suffix is not a platform `Int` merely because it was written plainly, and only the checker knows what it became; without this the evaluator built every such literal as a platform integer and the width a declaration promised was never enforced on it. The key is the span rather than its offsets, because two files hold a literal at the same offsets all the time and one table serves a program and everything it depends on.

- **This is over the 500-line default deliberately.** It is seventy-three definitions with a median of seven lines, more than fifty of them accessors over one record. Splitting it means either exporting the state's representation so a second module can reach it, or writing the accessors twice — both trade the encapsulation that makes the state safe for a smaller number. The limit is there to stop a module holding several subjects; this one holds exactly one.

- **A second name for a function inherits the first one's restrictions.** `inheritRestrictions` is
  how a qualifier or an alias keeps what the declaration asked for: the tables are keyed by the
  spelling a call resolves against, so a value bound under two names needs its restrictions recorded
  under both or the second one is unguarded.

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

- **Q:** Is one table of variants keyed by name enough? **A:** No; variants are held keyed by their owning type as well. _Rationale:_ a name-keyed table has one entry per name across every module in the graph, so two modules declaring a variant of the same name overwrite one another and the survivor depends on load order. Keyed by owner there is no collision to resolve, and a caller that already knows the type — which a pattern does, once its name has been resolved through the scope — asks a question with one answer. _Rejected:_ a name-keyed table with a tie-break; erroring on a duplicate name, which would refuse two modules that never meet.

- **Q:** Why a second map rather than a fourth component on `declaredVariants`? **A:** Because most variants have no names. _Rationale:_ absence is the answer for every positional variant, and a `Maybe` in a four-tuple would make every reader of the payload destructure a field they do not want. _Rejected:_ widening the existing tuple.
- **Q:** Why a separate module? **A:** Because the checking walk is already deep, and formation, unification, and state are independently testable concerns. _Rationale:_ the split follows a real seam rather than a line count alone. _Rejected:_ one large checker file.
- **Q:** When are obligations discharged? **A:** After the function body, not at the call. _Rationale:_ the argument type may be an inference variable at call time and only solved later; discharging after the body checks what the reader wrote, not a guess. _Rejected:_ discharging at the call site; deferring to module end, which loses the enclosing scope's bounds.
- **Q:** Imported or local signatures first? **A:** Imported interface bindings form an outer checker frame; local signatures form the inner frame. _Rationale:_ resolution rejects illegal conflicts and local checking cannot overwrite a dependency interface silently. _Rejected:_ one biased `Map.union`.
- **Q:** Model an integer literal as `Int` immediately? **A:** No; retain a deferred literal constraint. _Rationale:_ annotations and call parameters must select narrower or wider integer types before fit checking, while a context-free literal still defaults predictably. _Rejected:_ hard-coded `Int`; caller-wide numeric promotion; a special nominal literal type that cannot record its later solution.
- **Q:** May a nested construct finalize every pending literal? **A:** No; it records the next type-variable identity and selects only constraints in the required creation range. Even within that range, branch/result validation retains unsolved constraints for an enclosing context. _Rationale:_ an annotated `if` or `match`, and an expression used beside another literal, must not default before its outer context is applied. _Rejected:_ global finalization at each diagnostic boundary; count-based stack slicing that nested settlement can invalidate; carrying unresolved shape diagnostics to module end.

## Referenced by

[[src/Pudu/Type/_MOC]] · [[Type Check]]
