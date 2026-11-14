---
type: handoff
status: HANDED_OFF
issue: 516
aliases: [Native Text Method Delivery]
---
# Native Text Method Delivery

Delivery Owner → Backend Engineer → Test Engineer. Stacks on #515
(0e2c1219). Owned: Core.hs, Core/Frame.hs, Compiler/Lower/{Body,Text}.hs,
Compiler/Frame/Body.hs, Backend/Emit/State.hs, Backend/Emit/Frame/Value.hs,
Backend/Runtime{,/Dependencies,/Text/Methods}.hs, TextMethodPrograms.hs,
TextLeakSpec.hs, NativeSpec.hs, both cabal files and mirrors.

Backend Engineer → Test Engineer: the fifteen methods are implemented; the
method groups and the counted-leak run (17 programs) pass.

Evidence: 47 native groups under Clang and GCC 15, Str groups under Clang
ASan/UBSan, 17 counted-leak programs clean; all 20 clean gates pass with 696
groups.

Exact next action: #517 adds trim/toUpper/toLower with tables read from the
linked Data.Text.

## Referenced by

[[handoffs/_MOC]] · [[Native Emission Coverage]]
