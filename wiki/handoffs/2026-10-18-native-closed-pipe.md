---
type: handoff
status: HANDED_OFF
issue: 505
aliases: [Native Closed Pipe Delivery]
---
# Native Closed Pipe Delivery

Delivery Owner → Language Architect → Backend Engineer → Test Engineer.
[[Native Closed Pipe Semantics]] resolves ready P1 #505. Own Runtime process
startup/revision and Emit.Frame selection/call, BrokenPipeSpec/registration and
matching mirrors. Work on fix/505-native-closed-pipe stacked on c7343ddc; native
predecessors remain unmerged to dev. No subagents execute; preserve dist-ticky.

#504 passes all 19 clean gates/676 groups and both C compilers/sanitizers.
Its CLI probes expose the closed-output divergence: evaluator statuses 7/1/0
versus native signal 13. The scalar ledger and README are temporarily 3/14
(21%). Restore only after verifying this repair. Other wide source/frame and
full-language obligations remain pending. Independent reviews/additional
platforms remain promotion gates; no production-ready claim.

The regression has red evidence for original stdout termination and the
incomplete SIG_IGN-only stderr behavior. Final startup uses a rearmed caught
handler (default on exec), with default only during fatal stderr reporting;
cleanup precedes reporting, and startup disposition returns before exit-time
stdout flush. Final 27 launcher combinations pass under Clang/GCC 15 and
ASan/UBSan, and all 108 actual tree/compiled/native CLI cases agree, including
inherited blocked SIGPIPE. Evidence: ~/.codex/tmp/pudu-505-pipe/.

The deliberately cancelled earlier gate run remains archived in
validation-incomplete-stdout-only/. The clean validation/ run passed 18 gates;
all 677 groups ran and only the stale standard signal.h include whitelist failed.
The inspected one-header adjustment recompiled EmitSpec under -Werror and passed
its focused property, then the complete 677-group suite passed. Retain original
failure logs, header-hygiene.log and full-suite-recheck.log as distinct evidence.
No runtime source changed between that clean build and the successful recheck.
The scalar ledger/README returns to 4/14 (28%). This is local repair evidence,
not independent review or full language/platform readiness.

Test Engineer → Delivery Owner → Language Architect: #505 is ready for a local
commit. Exact next action: implement ready #506's optional wide-frame ABI and
executed Core/frame matrix, then admit source Int128/UInt128 with differential
coverage. Required independent review remains pending; no subagents execute.

## Referenced by

[[handoffs/_MOC]] · [[Native Closed Pipe Semantics]] · [[Native Wide Runtime Delivery]]
