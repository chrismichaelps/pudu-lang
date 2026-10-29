---
type: module
path: "@root/test/Pudu/Compiler/Program/Eval/ProtocolSpec.hs"
fidelity: Active
aliases: [Protocol Evaluation Spec]
tags: [module, test, runtime, serialization]
---
# Protocol Evaluation Spec

`testProtocolEvaluation :: IO Property` compiles and evaluates format, serialization, network and
service-boundary fixtures through the shared program test helper, then compares each returned
main value with its expected check count. Preserves all existing families and their explicit
counterexample labels. The program evaluation orchestrator includes the resulting conjunction.

For #739, run [[Std Binary Fixture]] and require its returned count to be 22. That fixture covers
primitive bits, every derived field kind, sums, wire goldens, evolution and typed corrupt-data
refusals. The CLI [[Binary Facade Gate]] independently checks process status and visible output.

## Resolved Grill Log

- **Q:** Does merely loading a fixture prove it executed? **A:** No; assert the exact returned
  count, and retain assertion failures as runtime failures through the shared compiler/evaluator.
- **Q:** Replace existing protocol families while adding binary tests? **A:** No; the new result
  participates in the same conjunction and every existing fixture and expected result remains.

## Referenced by

[[src/_MOC]] · [[Std Binary Fixture]] · [[Repository Test Runner]]
