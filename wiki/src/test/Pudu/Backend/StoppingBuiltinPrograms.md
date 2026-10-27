---
type: module
path: "@root/test/Pudu/Backend/StoppingBuiltinPrograms.hs"
fidelity: Active
aliases: [Backend Stopping Builtin Programs]
---
# Backend Stopping Builtin Programs

Export stoppingBuiltinSuccessPrograms (explicit stdout/stderr) and
stoppingBuiltinRefusalPrograms (runtime failures compared with the
interpreter). The healthy program renders and compares panic and
convertInteger values, stores panic in a record and returns it from a
function. Refusals cover panic after partial output inside a generic function
and a loop, multi-line and empty messages, non-text and missing arguments,
panic through an annotated binding, a captured record field and a returned
value, and untyped convertInteger directly and through a value after its
argument prints.

## Resolved Grill Log

Expectations come from the tree interpreter and are rechecked against the
compiled evaluator on every run. Positions where checking types panic as the
error type (#634) and native refuses, such as `fn(Int) -> Never` bindings or
arrays of panic, are left out until that bug is fixed; they refuse with E6001
rather than compile.

## Dependencies and consumers

[[Backend Output Callable Programs]] · [[Backend Native Tests]] · [[Backend Text Leak Tests]] · [[Pudu Test Cabal Manifest]]

## Referenced by

[[Native Stopping Builtins]] · [[src/Pudu/Backend/_MOC]]
