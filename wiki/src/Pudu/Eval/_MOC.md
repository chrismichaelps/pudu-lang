---
type: moc
tags: [moc, module]
---

# Evaluator Module Map

- [[Eval Entropy]] — bounded operating-system cryptographic entropy.
- [[Eval Hash Map]] — persistent indexed buckets and deterministic map order.
- [[Eval Bytes]] — compact byte values and their built-in operations.
- [[Eval Handle]] — runtime-owned streaming file handles.
- [[Eval Socket]] — runtime-owned TCP sockets and typed host outcomes.
- [[Eval Tls]] — secured connections held for one evaluation.
- [[Eval Concurrent]] — thread, channel, mutex, and atomic-cell tables.
- [[Eval Hash]] — digest, password-derivation, and collection-mixing primitives.
- [[Eval Install]] — a module's declarations into the environment, functions before constants.
- [[Eval Effect]] — the operations that reach outside the program, and the refusal that keeps them out of constant folding.
- [[Eval Builtin]] — the effects, built-in methods, and conversions the prelude wires in.
- [[Eval Builtin Definition]] — the closed wired-in function vocabulary and canonical source names.
- [[Eval Clock]] — calendar time and subprocesses.
- [[Eval Io]] — the effects a program may perform, each answering with an outcome.
- [[Eval Keyed]] — the runtime semantics of `Map` and `Set`, kept in key order by a balanced tree.
- [[Eval Order]] — which values may be keys, and the order they are compared by.
- [[Evaluator]] — declaration installation, statement and expression walking, and bounded execution.
- [[Eval Dispatch]] — array method dispatch (currently inline in Eval.hs, extraction planned).
- [[Eval Render]] — how a runtime value prints, and what a diagnostic calls its shape.
- [[Eval Method]] — the closed vocabulary of built-in methods a value answers to, and the name each is spelled by.
- [[Eval Value]] — runtime values, and the total order the keyed collections are held in.
- [[Eval Foreign]] — the call into a library written elsewhere, and every check made before the value leaves.
- [[Eval Env]] — environment frames, control unwinding, and abort diagnostics.
- [[Eval Match]] — total pattern matching against values.
- [[Eval Operator]] — unary, binary, member, index, and `?` semantics.
- [[Eval Array]] — Array[T] runtime values, indexing, iteration, and 42 accessor methods.

Dependency direction: Builtin Definition → Value → Env → Operator/Match/Array → Dispatch → Evaluator. No evaluator module imports a parser or resolver module other than [[Syntax Tree]].

## Referenced by

[[src/Pudu/_MOC]] · [[Semantics]]
