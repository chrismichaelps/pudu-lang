---
type: module
path: "@root/test/Pudu/Diagnostic/NativeSpec.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
aliases: [Native Diagnostic Contract Tests]
---
# Native Diagnostic Contract Tests

Export nativeDiagnosticProperties. All six failure constructors must preserve
their code, Error severity, nonempty source span, complete caller detail and
correct optional help. Plain rendering must retain the source column and code.

## Resolved Grill Log

Use one Unicode source and a nonzero span, plus multiline compiler output.
Check values and user-facing rendering; do not run a compiler or infer native
execution support from these constructor contracts. Focused/full registration
must share the same property.

## Referenced by

[[Native Diagnostic Contracts]] · [[Repository Test Runner]] · [[src/_MOC]]
