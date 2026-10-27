---
type: handoff
status: CLOSED
issue: 517
aliases: [Native Text Case Delivery]
---
# Native Text Case Delivery

Delivery Owner → Backend Engineer → Test Engineer. Stacks on #516
(59b77e3d). Owned: Core.hs, Compiler/Lower/Text.hs, Backend/Emit/Frame/
Value.hs, Backend/Runtime{,/Dependencies,/Text/Case}.hs, TextCaseSpec.hs,
TextMethodPrograms.hs, test/Main.hs, both cabal files and mirrors.

Finding: the build links text-2.1.4, not the boot 2.1.3 that global ghc
sees; tables derived in-process avoid the mismatch, and the issue text was
corrected.

Evidence: the case, Str method, text and counted-leak groups pass under
Clang, GCC 15 and Clang ASan/UBSan.

Exact next action: Char values (#518), which unlock charAt and Char literals.

## Referenced by

[[handoffs/_MOC]] · [[Native Emission Coverage]]
