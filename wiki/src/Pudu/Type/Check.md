---
type: module
path: "@root/src/Pudu/Type/Check.hs"
fidelity: Active
domain: "[[Pudu Type]]"
subsystem: "[[Semantics]]"
grammar: "[[grammar/haskell]]"
depth_score: 0.85
depth_status: DEEP
coupling: 6.0
interface_stability: 0.8
tags: [module, deep]
aliases: [Type Check]
---

# Type Check

## Purpose

Check every declaration, statement, and expression in a module against the types its declarations promise, inferring what the language allows to be left unwritten.

## Interface

### Signatures

```haskell
checkModule :: Module -> ([((Int, Int), Type)], [Diagnostic])
```

### Governance

- Signatures are collected before any body is checked, so a function may call one declared later, exactly as resolution already promised for names.
- Inference is local and bidirectional, matching [[architecture/SEMANTICS]]'s inference boundary: an absent annotation becomes a fresh variable the body solves, and no caller is ever inspected to type a callee.
- An exported function must annotate its parameters and its return type. An exported signature is a compatibility boundary that callers read without the body, so `E3010` asks for the annotation rather than inferring one.
- A declared generic parameter is rigid inside its declaration and is instantiated with fresh variables at every use, which is what lets one generic function serve several types.
- Every construct's rule is the one [[grammar/pudu]] states: an `if` condition is `Bool`, its reachable branches unify, `match` arms unify with each other and their patterns with the scrutinee, a loop is unit, and `return` is checked against the enclosing function's declared result.
- A member in callee position prefers a method over a field of the same name, so `value.name()` is a call and a field holding a function is reached by parenthesizing it.
- A record construction checks each field against its declaration and requires every declared field; an unknown field and a missing field are distinct diagnostics because they are distinct mistakes.
- `ErrorType` is poison: it unifies with everything, so one mistake produces one diagnostic instead of a cascade through every later use.
- The checker keeps its own name frames rather than reusing the resolver's symbol table. The duplication is deliberate and bounded; a shared resolved representation is the slice that removes it.

### Linkage

- **Requires:** [[Type Env]], [[Type Formation]], [[Type Unify]], [[Type Check Rule]], [[Type Check Pattern]], [[Type Check Method]], [[Syntax Tree]], [[grammar/pudu]], [[architecture/SEMANTICS]].
- **Consumed by:** [[Type Boundary]].

## Algorithm

Collect declared shapes and signatures, then walk each declaration: a function binds its parameters and checks its body against its result, a block checks statements and yields its trailing expression, and an expression is inferred and recorded against the span it occupies.

## Negative Logic (Prohibited Paths)

- No trait resolution or method dispatch, no `Result` or `Task` normalization, no exhaustiveness checking, no ownership or borrow analysis, no numeric-literal fitting, no defaulting of unsolved variables, and no caller-dependent inference.

## Edge Cases

- A pattern that names an unknown variant binds its sub-patterns at the error type, so the arm still checks without inventing a shape.
- A call with fewer arguments than parameters is accepted here because a parameter may declare a default; arity is only rejected when there are too many.
- `?` unwraps a `Result` and requires the enclosing function to return a `Result` carrying the same failure type; `E3011` reports the case where it does not. Conversion through `From` waits for trait resolution.
- `.await` currently passes its operand's type through, because task normalization belongs to the slice that introduces async execution.

## Depth

DEPTH 0.85 (DEEP). One entry point hides signature collection, scope construction, bidirectional inference, and the rules for every construct in the language.

## Grill Log

- **Q:** Infer exported signatures too? **A:** No; require the annotation. _Rationale:_ an exported signature is what callers compile against, and inferring it would let an unrelated body edit break them silently. _Rejected:_ whole-program inference; inferring and then freezing the first inferred shape.
- **Q:** How are cascades avoided? **A:** A failed unification yields `ErrorType`, which unifies with everything afterwards. _Rationale:_ the diagnostic contract requires that later phases not repeat a defect an earlier one already explained, and the same logic applies within a phase. _Rejected:_ aborting at the first error; suppressing by counting.
- **Q:** Should the checker reuse the resolver's symbols? **A:** Not yet. _Rationale:_ mapping references by span is fragile without a shared resolved tree, and the honest fix is that shared tree rather than a lookup that silently mismatches. _Rejected:_ span-keyed symbol lookup; merging the two phases.
- **Q:** What happens to `?` and `.await` now? **A:** They type as fresh variables and are documented as awaiting the failure and task slice. _Rationale:_ guessing `Result[T, E]` normalization before it is implemented would produce confident, wrong diagnostics. _Rejected:_ partial `Result` support; rejecting the syntax the parser already admits.

## Variants

- Trait bounds, `Result` and `Task` normalization, and exhaustiveness join later slices; each extends the rules rather than reshaping the walk.

## Referenced by

[[src/Pudu/Type/_MOC]] · [[Type Boundary]] · [[Type Env]] · [[Type Unify]] · [[architecture/SEMANTICS]]
