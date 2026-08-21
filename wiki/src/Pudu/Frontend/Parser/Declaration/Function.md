---
type: module
path: "@root/src/Pudu/Frontend/Parser/Declaration/Function.hs"
fidelity: Active
domain: "[[Pudu Program]]"
subsystem: "[[Frontend]]"
grammar: "[[grammar/haskell]]"
depth_score: 0.68
depth_status: MEDIUM
coupling: 6.0
interface_stability: 1.0
tags: [module, medium]
aliases: [Parser Function]
---

# Parser Function

## Purpose

Parse `async`/`fn` declarations into signature, parameter, return-type, and body syntax while diagnosing the generic forms that this slice does not yet represent.

## Interface

### Signatures

```haskell
parseFunction :: Visibility -> Parser (Located Declaration)
```

### Governance

- Visibility is supplied by the orchestrator that consumed `export`, so the function grammar never invents public API.
- `async` is an optional prefix of `fn` and is preserved as the declaration's async flag; nothing here assigns task or capability semantics.
- Function names use [[Parser Name]]'s `E1012` value-name rule; parameter names use the same rule, keeping `_` reserved for discard patterns.
- Parameters admit an optional `:` type through [[Parser Type]] and an optional `=` default through [[Parser Expression]]; the list admits one trailing comma and an empty list.
- Default-argument admissibility — module constants, earlier parameters, no caller locals, no async or unsafe work — is a semantic rule, so parsing preserves the expression and checks nothing.
- A `->` introduces the return type; its absence is legal syntax and leaves inference to the semantic phase.
- The body is either a block from [[Parser Block]] or `=` followed by one expression; a body is mandatory, and its opening `{` is accepted even when it begins a new line because a signature alone is never a complete declaration.
- Type parameters and `where` clauses are grammatical in [[grammar/pudu]] but have no [[Syntax Tree]] representation in this slice; each emits `E1033` once and is skipped by balanced bracket or keyword-bounded recovery rather than being silently dropped.
- A latched budget stops body parsing silently, so one `E1099` never cascades into a missing-body report.
- A missing body emits `E1032` and yields an `InvalidExpression` body, keeping the declaration node complete for later phases.
- Default expressions, the body, and every nested construct are charged to [[Parser State]]'s shared budget, while parameter iteration itself is guarded by required token progress rather than by depth, matching [[Parser Block]]: a long parameter list is ordinary input, but a malformed one cannot loop.

### Linkage

- **Requires:** [[Parser State]], [[Parser Name]], [[Parser Type]], [[Parser Expression]], [[Parser Block]], [[Token]], [[Syntax Tree]], [[grammar/pudu]].
- **Consumed by:** the future declaration orchestrator.

## Algorithm

Consume an optional `async`, require `fn`, validate the value name, reject and skip reserved generic syntax, parse a parenthesized parameter list with optional types and defaults, parse an optional `->` return type, then parse a block or `=` expression body and merge the keyword-to-body span.

## Negative Logic (Prohibited Paths)

- No export handling, type-parameter representation, trait or impl membership, arity or default-argument validation, return-type inference, async lowering, or body semantic checking.

## Edge Cases

- A hostile default expression reports one latched `E1099` and still yields a complete declaration node; a 520-parameter list is parsed in full.
- `fn f()` with no body reports one `E1032` and consumes nothing further; `fn f[T]()` reports one `E1033` and still parses the parameter list and body.
- An empty parameter list, a trailing comma, and a parameter with both a type and a default are all valid; a missing `)` reports one `E1001` without consuming the body.
- An expression body ends where the expression ends, so the next declaration on a new line is never absorbed.

## Depth

DEPTH 0.68 (MEDIUM). It composes five grammar modules behind one entry point and owns signature-level recovery for the forms this slice defers.

## Grill Log

- **Q:** Should this module consume `export`? **A:** No; it accepts the visibility the orchestrator resolved. _Rationale:_ the same rule that keeps illegal module `let` unrepresentable in [[Parser Binding]] keeps public API ownership in one place. _Rejected:_ parsing `export` in each declaration module.
- **Q:** How are type parameters and `where` clauses handled before their AST exists? **A:** Diagnose `E1033` once and skip the reserved region. _Rationale:_ silently ignoring them would accept programs whose meaning the compiler cannot yet represent, which [[grammar/pudu]] prohibits. _Rejected:_ dropping the tokens; parsing them into a placeholder node that later phases would have to trust.
- **Q:** Is a body optional for a declaration-only form? **A:** No; a missing body is `E1032` with an invalid body node. _Rationale:_ trait method signatures belong to the trait slice, which owns its own grammar. _Rejected:_ admitting bodiless functions at module scope.

## Referenced by

[[src/Pudu/Frontend/Parser/Declaration/_MOC]] · [[Parser State]] · [[Parser Name]] · [[Parser Type]] · [[Parser Expression]] · [[Parser Block]] · [[Syntax Tree]] · [[Frontend]]
