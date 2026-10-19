---
type: handoff
status: HANDED_OFF
issue: 511
aliases: [Native Floating Runtime Delivery]
---
# Native Floating Runtime Delivery

Delivery Owner → Language Architect → Backend Engineer → Test Engineer.
#510 is committed as 775f56b0 with all 20 clean gates/685 groups passing.
Own Runtime/Float.hs, Runtime/Dependencies.hs, Runtime.hs, Runtime/Float/Value.hs,
Emit/Support.hs, Emit/Frame.hs, FloatRuntimeSpec.hs, explicit registrations and
matching vault pages. Complete resolved mirrors precede implementation. No
subagents; preserve dist-ticky. Fresh dev lacks prerequisites, so stack on #510.

[[Native Floating Runtime]] adds exact buffered line output and the catalogue;
[[Native Runtime Dependencies]] unifies closure lookup without changing the
integer compatibility API. Selected float_target owns float.h/limits.h. Source,
Core/frame admission and representation changes remain successor obligations;
revision remains 7. Keep review partitions below 600 changed lines.

Backend Engineer → Test Engineer: actual catalogue/facade and printer are
implemented. Clang passes four focused properties: 1,042 output encodings,
19 minimal production roots, six write/flush outcomes and 18 closed-pipe states
plus two ordinary executions. GCC 15 and ASan/UBSan pass those checks and the
retained 54,344 arithmetic rows/6,780 natural rows. All focused handles exit
zero; LeakSanitizer is unavailable on this host and is not claimed. Progress
checking and its five generator tests pass. Evidence: ~/.codex/tmp/pudu-511/.

Clean validation: all 20 gates pass with 689 test groups after a fresh
optimized -Werror build. Evidence for this run is the scratch log of the
session that committed it; the earlier interrupted run in
~/.codex/tmp/pudu-511/validation/ is superseded.

Exact next action: #512 carries Float32/Float64 through Core, frames and
source admission, with Float/Bool entry rendering. Independent review and
additional platforms remain promotion requirements.

## Referenced by

[[handoffs/_MOC]] · [[Native Floating Runtime]] · [[Native Floating Runtime Tests]] · [[Native Runtime Dependencies]]
