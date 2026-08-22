---
type: moc
tags: [moc, module]
---

# Pudu Module Map

- [[Source]] — immutable source identity, cached scalar length, positions, and spans.
- [[Diagnostic Model]] — phase-independent structured diagnostics, deterministic ordering, and error gating.
- [[Compiler Pipeline]] — the fixed lex, parse, resolve phase boundary and error gate.
- [[src/Pudu/Semantic/_MOC|Semantic modules]] — symbols, scopes, the prelude layering, and name resolution.
- [[src/Pudu/Eval/_MOC|Evaluator modules]] — tree-walking execution, runtime values, and bounded control flow.
- [[src/Pudu/Repl/_MOC|REPL modules]] — the `puduci` session, its commands, and its structural outline.
- [[Diagnostic Render]] — human-readable diagnostics with source excerpts and carets.
- [[Pudu CLI]] — the `pudu` executable and its exit-status contract.
- [[src/Pudu/Frontend/_MOC|Frontend modules]] — lossless lexing, recovery-capable untyped syntax, and the complete first parser slice.

## Referenced by

[[src/_MOC]] · [[Frontend]]
