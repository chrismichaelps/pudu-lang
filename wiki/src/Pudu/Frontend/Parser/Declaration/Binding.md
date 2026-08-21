---
type: module
path: "@root/src/Pudu/Frontend/Parser/Declaration/Binding.hs"
fidelity: Active
domain: "[[Pudu Program]]"
subsystem: "[[Frontend]]"
grammar: "[[grammar/haskell]]"
depth_score: 0.66
depth_status: MEDIUM
coupling: 5.0
interface_stability: 1.0
tags: [module, medium]
aliases: [Parser Binding]
---

# Parser Binding

## Purpose

Parse module constants and block-local `let`, `var`, and `const` bindings while preserving visibility, mutability policy, optional type syntax, initializer structure, and exact source spans.

## Interface

### Signatures

```haskell
type BlockParser = Parser (Located Block)

parseTopConst :: Visibility -> BlockParser -> Parser (Located Declaration)
parseLocalBinding :: BlockParser -> Parser (Located Declaration)
```

### Governance

- Module scope admits only `const`; `let` and `var` remain block-local so parsing cannot invent module-load execution or global mutable state.
- `parseTopConst` preserves the orchestrator-supplied private/exported visibility; local bindings are always private syntax nodes.
- `let` maps to `Immutable`, `var` to `Mutable`, and `const` to `CompileTime`.
- `let`/`var` names use [[Parser Name]]'s `E1012` value-name rule; constants use its `E1013` `UPPER_SNAKE_CASE` rule.
- A `:` introduces [[Parser Type]] syntax and `=` is mandatory through the state-owned `E1001` expectation.
- Initializers use [[Parser Expression]] with an injected block capability, preventing a Haskell module cycle.
- Missing initializers retain `InvalidExpression` with `E1040`; an existing expression-budget `E1099` is not followed by a binding-specific cascade.
- A non-`const` module keyword and a non-binding local keyword are each rejected once with `E1001` and recovered as `InvalidDeclaration`; the offending token is consumed so declaration and block parsing keep making progress without a name/type/initializer cascade.

### Linkage

- **Requires:** [[Parser State]], [[Parser Name]], [[Parser Type]], [[Parser Expression]], [[Token]], [[Syntax Tree]], [[grammar/pudu]].
- **Consumed by:** the future declaration orchestrator and block parser.

## Algorithm

Inspect the leading keyword without consuming it, reject an unadmitted keyword once, otherwise choose a closed binding kind from the admitted keyword, validate its identifier class, parse an optional type after `:`, require `=`, delegate initializer parsing through the supplied block capability, and merge the keyword-to-initializer span.

## Negative Logic (Prohibited Paths)

- No module `let`/`var`, exported local, implicit initializer, semicolon ownership, type inference, constant evaluation, name resolution, or ownership checking.

## Edge Cases

- Missing `=` diagnoses without consuming the following expression; missing initializer yields an invalid recovery node; multiline boundaries remain trivia-insignificant and are determined by the closed expression grammar.
- `let`/`var` at module scope produce exactly one `E1001` and no fabricated constant name; an exhausted expression budget leaves the surrounding binding node intact with only the owning `E1099`.

## Depth

DEPTH 0.66 (MEDIUM). It centralizes scope-sensitive binding grammar, name-class validation, type/expression delegation, recovery, and span construction behind two narrow entry points.

## Grill Log

- **Q:** One context flag or two entry points? **A:** Expose separate top-constant and local-binding operations. _Rationale:_ the API makes illegal module `let`/`var` unrepresentable to orchestration. _Rejected:_ Boolean scope flags; one permissive parser plus later rejection.
- **Q:** Should the module import the future block parser? **A:** No; accept a block capability passed to expression parsing. _Rationale:_ declaration/block/expression recursion stays explicit without `hs-boot`. _Rejected:_ monolithic declaration module; cyclic imports.
- **Q:** How does an unadmitted keyword recover? **A:** Emit one `E1001`, consume the token, and return `InvalidDeclaration`. _Rationale:_ callers keep progress while diagnostics stay cascade-free. _Rejected:_ parsing the wrong keyword as a `let` binding, which fabricated a name and emitted three stacked `E1001` diagnostics at one offset; non-consuming rejection, which lets an orchestrator loop.
- **Q:** Does parsing enforce constant evaluation or binding inference? **A:** No; it preserves syntax and diagnostics only. _Rationale:_ [[architecture/SEMANTICS]] assigns those rules to later semantic phases. _Rejected:_ parser-time evaluation or typing.

## Variants

- Pattern bindings require a complete pattern AST and semantic slice before extending these entry points.

## Referenced by

[[src/Pudu/Frontend/Parser/Declaration/_MOC]] · [[Parser State]] · [[Parser Name]] · [[Parser Type]] · [[Parser Expression]] · [[Token]] · [[Syntax Tree]] · [[Frontend]]
