---
type: handoff
status: ACTIVE
issue: 518
aliases: [Native Char Delivery]
---
# Native Char Delivery

Delivery Owner → Backend Engineer → Test Engineer. Stacks on #517
(ac40bf0e). Owned: Core.hs, Core/Frame.hs, Compiler/Lower/{Types,Scalar,
Text,Body}.hs, Compiler/Frame/Body.hs, Backend/Emit/Frame{,/Value,/Body}.hs,
Backend/Runtime{,/Frame,/Dependencies,/Char,/Text/Case}.hs, CharPrograms.hs,
NativeSpec, TextLeakSpec, FloatRuntimeSpec, both cabal files and mirrors.

Finding: #517's commit failed the clean gate's float catalogue check; the
fix was folded into that commit before this branch was cut again.

Evidence: all backend groups pass at -O0 under Clang; the Char, leak, case,
Str method and float runtime groups pass under GCC 15 and Clang ASan/UBSan.

All 20 clean gates pass (21c7726c). The first run caught a stale EmitSpec
expectation that Char refuses; the refusal fixtures now use BigInt and
`charFromCode`.

Exact next action: native tuples (boxed, refcounted cells), then records once
#519 (declared field order) is in the base.

## Referenced by

[[handoffs/_MOC]] · [[Native Emission Coverage]]
