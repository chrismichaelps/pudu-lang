---
type: moc
tags: [moc, module]
---

# Evaluator Module Map

- [[Evaluator]] — declaration installation, statement and expression walking, and bounded execution.
- [[Eval Value]] — runtime values and how a session renders them.
- [[Eval Env]] — environment frames, control unwinding, and abort diagnostics.
- [[Eval Match]] — total pattern matching against values.
- [[Eval Operator]] — unary, binary, member, index, and `?` semantics.

Dependency direction: Value → Env → Operator/Match → Evaluator. No evaluator module imports a parser or resolver module other than [[Syntax Tree]].

## Referenced by

[[src/Pudu/_MOC]] · [[Semantics]]
