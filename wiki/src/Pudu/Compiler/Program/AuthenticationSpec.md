---
type: module
path: "@root/test/Pudu/Compiler/Program/AuthenticationSpec.hs"
fidelity: Active
tags: [database, authentication]
aliases: [Database Challenge Spec]
---
# Database Challenge Spec

## Purpose and interface

Register the authenticationProperties family in the repository suite and its test manifest. Compile the deterministic Database challenge fixture and run its entry in both evaluator modes, preserving the previous mode setting.

## Algorithm and resolved Grill Log

Require an actual compiled module, expected zero output and no error diagnostics. Return all mode outcomes as one focused property family. Pure rejection tests and observed session exchanges live in the fixture so carried and source-only executions run the same assertions.

- **Q:** Compare only the modes? **A:** No; each must answer the expected output without an error.
- **Q:** Leave mode settings changed? **A:** No; restore them on every exit.

## Referenced by

[[Repository Test Runner]] · [[src/pudu-tests-cabal|Pudu Test Manifest]] · [[Database Challenge Fixture]] · [[src/_MOC]]
