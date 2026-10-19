---
type: handoff
status: HANDED_OFF
issue: 512
aliases: [Native Floating Source Delivery]
---
# Native Floating Source Delivery

Delivery Owner → Language Architect → Backend Engineer → Test Engineer.
#511 is committed as 14406830 with all 20 clean gates/689 groups passing.
Branch feature/512-native-float-source stacks on it because dev lacks the
native prerequisites. Owned: Core.hs, Core/Frame.hs, Compiler/Lower/{Types,
Body,Scalar}.hs, Compiler/Frame/Body.hs, Backend/Emit/{Support,Frame}.hs,
Backend/Emit/Frame/{Body,Value}.hs, Backend/Runtime{,/Frame}.hs,
FloatPrograms.hs, NativeSpec.hs, pudu-tests.cabal and their mirrors. No
subagents; dist-ticky stays untouched.

Backend Engineer → Test Engineer: float transport, operators, refusals and
Bool/Float entry rendering are implemented. Focused evidence: the float
corpus, all 42 native groups under Clang and GCC 15, float groups under Clang
ASan/UBSan, CLI parity for open and closed stdout.

Clean validation: all 20 gates pass with 691 groups. The first clean run
failed two groups for test reasons only: a stale Float32 refusal fixture and
expected float answers that GHC folds differently at -O2. Both are fixed and
the float groups pass at -O0 and -O2.

Exact next action: #513 makes `print`/`display` calls respect local and
module-function shadowing, as the interpreter does.

## Referenced by

[[handoffs/_MOC]] · [[Native Emission Coverage]]
