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

Finding: tuple ordering with a NaN member contradicts itself in the
interpreter (#522, fixed on its own branch). Native matches the current
interpreter here and moves to the total order once #522 is merged in.

Evidence: all 81 backend groups pass; the tuple and leak groups pass under
GCC 15 and Clang ASan/UBSan.

Exact next action: merge #519 and #522 into this stack, move native float
member ordering to the total order, then run the clean gates.

## Referenced by

[[handoffs/_MOC]] · [[Native Emission Coverage]]
