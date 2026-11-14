---
type: handoff
status: HANDED_OFF
issue: 513
aliases: [Native Builtin Shadowing Repair]
---
# Native Builtin Shadowing Repair

Delivery Owner → Backend Engineer → Test Engineer. Stacks on #512
(bf645a8b). Owned: Compiler/Lower/Body.hs, FunctionPrograms.hs, EmitSpec.hs
and their mirrors.

Finding: native printed the builtin `display` rendering where the interpreter
called the module's own `fn display`. Lowering now resolves locals, then
module functions, then builtins. Focused native function and refusal groups
pass.

Clean validation: all 20 gates pass with 691 groups.

Exact next action: #515 adds owned `Str` values. Method calls must keep the
evaluator's argument-before-receiver order recorded in #514.

## Referenced by

[[handoffs/_MOC]] · [[Native Emission Coverage]]
