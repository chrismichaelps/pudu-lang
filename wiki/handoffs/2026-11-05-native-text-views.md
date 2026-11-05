---
type: handoff
status: ACTIVE
issue: 827
aliases: [Native Text View Delivery]
---
# Native Text View Delivery

Architect → Backend Engineer. Fresh feature/827-native-text-views starts at
dev 82ae132e. Own Core, Lower.Text/Body/Intrinsic, Emit.Frame.Value/TextView,
Runtime.Text.Methods and the compiler manifest. Test ownership is
TextViewPrograms plus NativeSpec/ModulePrograms/TextLeakSpec/FrameEmitSpec
registry/carrier edits, test manifest and complete mirrors. Navigation,
architecture, native ledger and history stay aligned. No subagents.

Backend Engineer → Test Engineer → Forensic Guardian self-audit. All six
primitives now share guarded lowering and runtime/frame kernels; eight explicit
success programs, nine failures/entries and 52 frame controls pass. Counted
cleanup executes all eight kernel programs. The public StringView facade now
passes after integrating #825 at dev b9038686, including imported defaults,
byte iteration, shared substrings, mutable copy and byte searches.

Strict Clang, GCC 15 and ASan/UBSan pass with both evaluators. All 48 clean
optimized gates and initial-head CI pass. PR #829 now integrates query delivery
from dev 88829715; combined focused checks and final-head CI are next.
No independent review is claimed.

Exact next action: verify the combined text/query compiler matrix and final-head
CI, then obtain independent review or an explicit owner exception before merge.

## Referenced by
[[handoffs/_MOC]] · [[Native Text Views]]

All six initial native probes now match evaluator results. The larger corpus
exposed a pre-existing call-order contradiction, tracked in #828; the native
ledger marks scalar-function coverage Partial until that obligation is resolved.
The kernel slice preserves existing engine parity and does not change call semantics.
