---
type: moc
tags: [moc]
aliases: [Backend Module Map]
---

# Backend Module Map

- [[Backend Frame Program]] · [[Backend Frame Runtime]] · [[Native Frame Runtime Tests]] — deterministic assembly, heap ownership and iterative calls.

- [[Backend Frame Values]] · [[Backend Frame Bodies]] — pure operations and suspending bodies over typed frame cells.
- [[Native Frame Body Tests]] — strict C11 corpus compilation and call-suspension checks.

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

- [[Backend Runtime Integer]] · [[Backend Integer Programs]] — defined C11 bit patterns, wrapping, saturation and checked shifts.

- [[Backend Integer Value]] · [[Backend Integer Arithmetic]] · [[Backend Integer Bits]] · [[Backend Deferred Integer Programs]] — exact integer carriers and deferred-value conformance.

- [[Backend Word128 Kernel]] · [[Native Word128 Tests]] — portable 128-bit arithmetic prerequisite.

- [[Backend Wide Integer Values]] · [[Native Wide Value Tests]] — exact signs and selectable dependencies (#502).

- [[Backend Wide Operations]] · [[Native Wide Operation Tests]] — planned typed primitive implementation (#503).

- [[Backend Wide Integer Display]] · [[Native Wide Runtime Tests]] — actual wide runtime integration (#504).

- [[Native Broken Pipe Tests]] — actual emitted startup under default SIGPIPE (#505).

- [[Native Wide Frame Tests]] — exact wide frame execution (#506).

- [[Native Floating Natural Kernel]] · [[Native Floating Natural Tests]] — exact formatting prerequisite (#508).

- [[Native Binary64 Formatter]] · [[Native Binary64 Formatter Tests]] — exact decimal text (#509).

- [[Native Floating Values]] · [[Native Floating Value Tests]] — exact bit transport and arithmetic (#510).

- [[Native Floating Runtime]] · [[Native Runtime Dependencies]] · [[Native Floating Runtime Tests]] — actual catalogue integration (#511).
