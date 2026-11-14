---
type: handoff
status: HANDED_OFF
issue: 515
aliases: [Native Owned Text Delivery]
---
# Native Owned Text Delivery

Delivery Owner → Language Architect → Backend Engineer → Test Engineer.
Stacks on #513 (f75f883d). Owned: Core.hs, Core/Frame.hs, Compiler/Lower/
{Types,Signature,Control,Body,Scalar}.hs, Compiler/Frame/{State,Body}.hs,
Backend/Emit/{Support,Frame}.hs, Backend/Emit/Frame/{Body,Value}.hs,
Backend/Runtime{,/Frame,/Text,/Dependencies}.hs, TextPrograms.hs,
TextLeakSpec.hs, the touched specs, both cabal files and their mirrors.

Backend Engineer → Test Engineer: Str values, operators, rendering, printing
and entries are implemented; text conformance and the counted-leak run pass.

Evidence: 45 native groups under Clang and GCC 15, text groups under Clang
ASan/UBSan, counted-leak runs clean, CLI parity for Str entries and a 2 MB
print loop with open and closed stdout. All 20 clean gates pass with 694
groups.

Exact next action: #516 adds the Str methods whose results are Int, Bool or
Str, keeping the evaluator's argument-before-receiver order (#514).

## Referenced by

[[handoffs/_MOC]] · [[Native Emission Coverage]]
