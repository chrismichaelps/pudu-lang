---
type: moc
tags: [moc, module]
---

# Pudu Module Map

- [[Source]] — immutable source identity, cached scalar length, positions, and spans.
- [[Diagnostic Model]] — phase-independent structured diagnostics, deterministic ordering, and error gating.
- [[Integer Literal]] — shared arbitrary-precision integer decoding, suffix vocabulary, and concrete-type fit laws.
- [[Float Literal]] — shared floating suffixes, total conversion, overflow detection, and runtime precision normalization.
- [[Compiler Pipeline]] — the fixed lex, parse, resolve, type phase boundary and error gate.
- [[src/Pudu/Compiler/_MOC|Program compiler modules]] — dependency discovery, module graph ordering, and cross-module interface orchestration.
- [[src/Pudu/Semantic/_MOC|Semantic modules]] — symbols, scopes, the prelude layering, and name resolution.
- [[src/Pudu/Type/_MOC|Type modules]] — type formation, unification, and bidirectional checking.
- [[src/Pudu/Eval/_MOC|Evaluator modules]] — tree-walking execution, runtime values, and bounded control flow.
- [[src/Pudu/Doc/_MOC|Documentation modules]] — the searchable index of what a program declares, and the type search over it.
- [[src/Pudu/Repl/_MOC|REPL modules]] — the `puduci` session, its commands, and its structural outline.
- [[Diagnostic Render]] — human-readable diagnostics with source excerpts and carets.
- [[Pudu CLI]] — the `pudu` executable and its exit-status contract.
- [[src/Pudu/Frontend/_MOC|Frontend modules]] — lossless lexing, recovery-capable untyped syntax, and the complete first parser slice.

## Referenced by

[[src/_MOC]] · [[Frontend]]
