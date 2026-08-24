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

- Every rule is the one [[grammar/pudu]] states for that construct; nothing here invents a coercion the language does not have.
- A name is instantiated at every use, so a declared generic serves several types without leaking one use's solution into another.
- A shape the rules cannot type produces a diagnostic naming the type it found, never a silent error type without explanation.
- These rules never recurse into sub-expressions; the walk in [[Type Check]] owns that, which is what keeps the two modules free of a cycle.
- Record-pattern owner annotations are formed through `declaredNames` using their full qualified path, so imported nominal identity is canonical and two equal basenames from different modules cannot unify accidentally. Constructor patterns continue to resolve through the variant table because the AST carries the constructor spelling rather than an owner path.
- Literal patterns register the same deferred integer constraints as expressions. A range checks both endpoints against the subject, so suffix selection and exact fit cannot be bypassed through the upper bound.

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

- **Q:** Why not inline these into the walk? **A:** The walk would exceed the reviewable size, and these rules are the part a reader checks against the grammar. _Rationale:_ they are a table, and a table is easier to audit alone. _Rejected:_ inlining; a generic operator-table abstraction.
- **Q:** Is checking only a range's lower endpoint sufficient? **A:** No; form and unify both endpoints. _Rationale:_ otherwise an out-of-range upper literal reaches exhaustiveness and evaluation without the numeric contract being enforced. _Rejected:_ trusting the parser; checking only the endpoint used to infer subject type.

## Referenced by

[[src/Pudu/Type/_MOC]] · [[Type Check]]
