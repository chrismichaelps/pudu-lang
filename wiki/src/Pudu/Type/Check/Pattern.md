---
type: module
path: "@root/src/Pudu/Type/Check/Pattern.hs"
fidelity: Active
domain: "[[Pudu Type]]"
subsystem: "[[Semantics]]"
grammar: "[[grammar/haskell]]"
depth_score: 0.5
depth_status: MEDIUM
coupling: 3.0
interface_stability: 0.8
tags: [module, medium]
aliases: [Type Check Pattern]
---

# Type Check Pattern

## Purpose

Own checking patterns against the type they match for [[Type Check]].

### Governance

- A record's declared field types are instantiated with the arguments the subject carries, exactly as a sum's payload already was. Matching a `Boxed[Int]` gives the field `Int` rather than the declaration's rigid parameter.

- Every rule is the one [[grammar/pudu]] states for that construct; nothing here invents a coercion the language does not have.
- A name is instantiated at every use, so a declared generic serves several types without leaking one use's solution into another.
- A shape the rules cannot type produces a diagnostic naming the type it found, never a silent error type without explanation.
- These rules never recurse into sub-expressions; the walk in [[Type Check]] owns that, which is what keeps the two modules free of a cycle.
- Record-pattern owner annotations are formed through `declaredNames` using their full qualified path, so imported nominal identity is canonical and two equal basenames from different modules cannot unify accidentally. Constructor patterns continue to resolve through the variant table because the AST carries the constructor spelling rather than an owner path.
- Literal patterns register the same deferred integer constraints as expressions. A range checks both endpoints against the subject, so suffix selection and exact fit cannot be bypassed through the upper bound.

- **A record pattern reaches a sum only through a variant that named its payload.** `case Circle{radius}` names one variant, so the subject is that variant's owner and the fields stand for its payload; a record type's own pattern names no variant and takes the other path.
- **A variant that named its payload is not matched by position** (`E3034`). One spelling reaches the value, so the other could only ever fail to match — and it would fail at run time, in a program the checker had accepted.
- The variant's own type is instantiated at the pattern, exactly as a positional constructor's already was, so matching a `Chain[Int]` gives the field `Int` rather than the declaration's rigid parameter.

### Linkage

- **Requires:** [[Type Env]], [[Type Unify]], [[Type Value]], [[Syntax Tree]].
- **Consumed by:** [[Type Check]].

## Algorithm

Dispatch on the operator, the receiver's type, or the pattern's shape, unifying against what the construct requires.

## Negative Logic (Prohibited Paths)

- No expression recursion, no trait lookup, no numeric promotion, and no exhaustiveness reasoning.

## Edge Cases

- An unsolved receiver produces a fresh variable rather than a diagnostic, so a member access on a not-yet-known type is not prematurely rejected.
- Integer pattern endpoints remain arbitrary precision until the match subject or enclosing literal finalization selects their type; both endpoints receive the selected type's fit check.

## Depth

DEPTH 0.50 (MEDIUM). It isolates the closed rules from the walk that applies them.

## Grill Log

- **Q:** Resolve a constructor pattern by its bare name against the table of every loaded module's variants? **A:** No; resolve the written name through the scope first, then read the shape under the type that owns it. _Rationale:_ two modules may each declare a variant called `Text`, and a bare-name table holds one of them — so a pattern matched whichever module was loaded last, which is not a property of the module being checked. It also meant a module imported only qualified put its constructors into a scope that never named them, and the same program checked one way alone and another way as part of a larger graph. The bare-name lookup remains as a fallback, so a wired-in variant reached without an import still matches. _Rejected:_ keeping the flat table; making the qualifier significant only when written.

- **Q:** Why refuse a positional pattern rather than make it work? **A:** Because making it work needs the field order where the match runs, and the declaration is the only place that has it. _Rationale:_ admitting both spellings without one representation is what let a type-correct program find no arm; refusing one spelling removes the divergence at its source instead of reconciling it downstream. _Rejected:_ carrying the field order into matching; normalising the value at construction.
- **Q:** Why not inline these into the walk? **A:** The walk would exceed the reviewable size, and these rules are the part a reader checks against the grammar. _Rationale:_ they are a table, and a table is easier to audit alone. _Rejected:_ inlining; a generic operator-table abstraction.
- **Q:** Is checking only a range's lower endpoint sufficient? **A:** No; form and unify both endpoints. _Rationale:_ otherwise an out-of-range upper literal reaches exhaustiveness and evaluation without the numeric contract being enforced. _Rejected:_ trusting the parser; checking only the endpoint used to infer subject type.

## Referenced by

[[src/Pudu/Type/_MOC]] · [[Type Check]]
