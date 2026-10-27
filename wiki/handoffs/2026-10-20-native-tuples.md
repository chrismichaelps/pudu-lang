---
type: handoff
status: ACTIVE
issue: 521
aliases: [Native Tuple Delivery]
---
# Native Tuple Delivery

Delivery Owner → Backend Engineer → Test Engineer. Stacks on #518
(b5ebf72e). Owned: Core.hs, Core/Frame.hs, Compiler/Lower/{Types,Scalar,
Body,Tuple}.hs, Compiler/Frame/Body.hs, Backend/Emit/{Aggregate,Frame,
Frame/Value,Frame/Body,Support}.hs, Backend/Runtime{,/Frame,/Dependencies,
/Aggregate}.hs, TuplePrograms.hs, NativeSpec, TextLeakSpec, FrameEmitSpec,
FloatRuntimeSpec, both cabal files and mirrors.

Finding: tuple ordering with a NaN member contradicted itself in the
interpreter (#522, fixed on its own branch). #519 and #522 are merged into
this stack and native follows the total order through `pudu_float_order`.

Evidence: all 81 backend groups pass; the tuple and leak groups pass under
GCC 15 and Clang ASan/UBSan.

Records landed in the same issue: they share the box, and their layout comes
from `declaredRecords`. All 83 backend groups pass; tuple, record and leak
groups pass under GCC 15 and Clang ASan/UBSan.

Exact next action: run the clean gates on this commit, then sums and
Option/Result (a new issue), which unlock print Result, charFromCode and the
Option-result Str methods.

## Referenced by

[[handoffs/_MOC]] · [[Native Emission Coverage]]
