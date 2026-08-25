---
type: moc
tags: [moc, module]
---

# Evaluator Module Map

- [[Eval Io]] — the effects a program may perform, each answering with an outcome.
- [[Eval Keyed]] — the runtime semantics of `Map` and `Set`, kept in key order.
- [[Eval Order]] — the total order keyed collections need, and the values that lack one.
- [[Evaluator]] — declaration installation, statement and expression walking, and bounded execution.
- [[Eval Dispatch]] — array method dispatch (currently inline in Eval.hs, extraction planned).
- [[Eval Value]] — runtime values and how a session renders them.
- [[Eval Env]] — environment frames, control unwinding, and abort diagnostics.
- [[Eval Match]] — total pattern matching against values.
- [[Eval Operator]] — unary, binary, member, index, and `?` semantics.
- [[Eval Array]] — Array[T] runtime values, indexing, iteration, and 42 accessor methods.

Dependency direction: Value → Env → Operator/Match/Array → Dispatch → Evaluator. No evaluator module imports a parser or resolver module other than [[Syntax Tree]].

## Referenced by

[[src/Pudu/_MOC]] · [[Semantics]]
