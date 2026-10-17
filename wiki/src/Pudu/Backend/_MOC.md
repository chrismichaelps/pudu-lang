---
type: moc
tags: [moc]
aliases: [Backend Module Map]
---

# Backend Module Map

- [[Backend Emit]] — deterministic C11 emission from [[Core IR]], including
  the diagnostic site tables that give native refusals the interpreter's text.

- [[Backend Runtime]] — the versioned C runtime translation unit embedded in
  every generated program: checked arithmetic, printing, failure rendering,
  exit-status clamping.

- [[Backend Toolchain]] — discovery, invocation, bounded capture, timeout, and
  atomic publication of the native [[Compilation Artifact]]; the only place a
  process is started.

- [[Compiler Lower]] — checked tree to [[Core IR]], with typed `E6001`
  refusals for everything the native subset does not carry.

- [[Backend Emit Tests]] · [[Backend Native Tests]] — the two specs that hold
  lowering, emission, and native execution to their documented promises.

## Referenced by

[[src/Pudu/_MOC]] · [[src/_MOC]] · [[Backend]]

## Native function delivery (#488)

- [[Backend Emit State]]
- [[Backend Emit Support]]
- [[Compiler Lower Body]]
- [[Compiler Lower State]]
- [[Compiler Lower Signature]]
- [[Backend Function Programs]]
- [[Backend Toolchain Tests]]

- [[Compiler Lower Control]] — resolved scalar loop targets, transfers and divergence (#489).

- [[Backend Control Programs]] — differential loop-control, divergence and transfer cases (#489).
