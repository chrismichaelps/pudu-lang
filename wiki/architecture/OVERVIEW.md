---
type: architecture
tags: [architecture]
aliases: [Compiler Architecture]
---

# Compiler Architecture

## Purpose

Implement the [[Pudu Language]] as explicit, independently testable phases while keeping syntax policy, semantic policy, runtime behavior, and native emission separate.

## Pipeline

1. [[Source Text]] enters [[Frontend]].
2. [[Lexer]] produces tokens and lexical [[Diagnostic]] values.
3. [[Parser]] produces a recovery-capable untyped syntax tree.
4. [[Name Resolution]] assigns declarations and lexical scopes.
5. [[Type Checking]] produces typed syntax, verifies generics, effects, and exhaustive matching.
6. [[Ownership Checking]] verifies moves, shared borrows, exclusive borrows, and region lifetimes.
7. Lowering produces [[Core IR]] with explicit control flow and ownership operations.
8. [[Interpreter]] evaluates typed/core programs for REPL and conformance.
9. [[Native Backend]] emits portable C11, then crosses the [[Native Toolchain]] seam to produce a native [[Compilation Artifact]].
10. [[Tooling]] reuses the same source, syntax, semantic, and diagnostic models.

## Dependency Direction

`Source/Diagnostic → Frontend → Semantics → Core IR → Runtime or Backend`. Tooling may consume phase APIs but phases never import Tooling. Runtime never imports parser structures.

## Delivery Sequence

Each vertical slice includes syntax, semantics, diagnostics, interpreter behavior, backend behavior where applicable, examples, and tests. Advanced proposal features are admitted only after their semantic rules are vault-complete.

## Negative Logic

- No global mutable compiler context.
- No backend knowledge in parser or type checker modules.
- No source-position loss across recovery or lowering.
- No native compiler stderr exposed as an untyped application error.
- No feature considered complete from parser acceptance alone.

## Grill Log

- **Q:** Should the first backend emit LLVM directly? **A:** No; emit auditable portable C11 behind [[Native Toolchain]]. _Rationale:_ it minimizes dependency and API risk while preserving native delivery. _Rejected:_ direct LLVM bindings (large unstable surface); assembly emission (non-portable and premature).
- **Q:** Should parsing and typing share one AST? **A:** No; keep untyped syntax and typed/core representations distinct. _Rationale:_ phase ownership improves diagnostics and prevents partial semantic state from leaking backward. _Rejected:_ one annotated AST (simpler initially, increasingly coupled).
- **Q:** Should the interpreter execute raw syntax? **A:** No; execute checked core representations. _Rationale:_ one semantic meaning must feed both execution paths. _Rejected:_ syntax-tree interpreter (semantic duplication).

## Variants

- Direct LLVM backend remains a post-v1 optimization option once the core semantics and C conformance suite are stable.
- A bytecode VM may later improve REPL startup but is not required to establish semantics.

## Referenced by

[[architecture/_MOC]] · [[ADR-0002-compiler-pipeline]] · [[Frontend]] · [[Semantics]] · [[Runtime]] · [[Backend]] · [[Tooling]]
