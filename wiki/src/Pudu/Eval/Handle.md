---
type: module
path: "@root/src/Pudu/Eval/Handle.hs"
fidelity: Active
domain: "[[Pudu Program]]"
subsystem: "[[Runtime]]"
grammar: "[[grammar/haskell]]"
tags: [module, runtime, io, streaming]
aliases: [Eval Handle]
---
# Eval Handle
## Purpose
Own one evaluation's open file handles and expose chunked reads/writes through opaque tokens.
## Interface
Opens readers/writers/appenders, reads and writes byte chunks, flushes/closes one handle, and closes
the remaining handles in that evaluation's store at teardown.
## Governance and algorithm
Tokens are never reused within a store; EOF is distinct from an empty chunk; host exceptions are
caught into `IoOutcome`; teardown flushes buffered output. Stores are never process-global, so one
evaluation cannot resolve or close another evaluation's token.
## Grill Log
- **Q:** Store `Handle` directly in runtime values? **A:** No. _Rationale:_ evaluator values copy,
  while a stream position is one identity-bearing resource. _Rejected:_ finalizer-only cleanup.
- **Q:** Share one table between embedded programs? **A:** No. _Rationale:_ program teardown must
  close only resources acquired by that program. _Rejected:_ process-global clearing.
## Referenced by
[[src/Pudu/Eval/_MOC]] · [[Std Io]] · [[Eval Effect]]
