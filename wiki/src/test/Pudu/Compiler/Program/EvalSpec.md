---
type: module
path: "@root/test/Pudu/Compiler/Program/EvalSpec.hs"
fidelity: Active
aliases: [Program Evaluation Tests]
---
# Program Evaluation Tests

Export evalProperties, testProgramEvaluation and testLinkedNames. Programs
with imports are compiled and their entry evaluated: the data, protocol,
service, runtime and compiled-agreement groups, the import-chain fixture
whose aliases must not be republished, and the default-scope fixture.

## Default scope (#639)

test-fixtures/defaultscope calls another module's function whose default
names that module's constant, from a module that declares its own constant
of the same name.

## Resolved Grill Log

The same-named caller constant catches the silent dynamic-scope case as well
as the undefined-name one; the expected value is the declaring module's.

## Referenced by

[[Eval Call]] · [[src/_MOC]]
