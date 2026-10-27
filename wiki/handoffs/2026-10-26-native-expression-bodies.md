---
type: handoff
status: SUPERSEDED
issue: 567
aliases: [Native Expression Body Delivery]
---
# Native Expression Body Delivery

Language Architect → Backend Engineer → Test Engineer → Forensic Guardian
self-audit. [[Native Expression Bodies]] resolves
the contract and bounded ownership. Branch feature/567-native-expression-bodies
starts at fetched dev and fast-forwards the #566 dependency. No sub-agents;
independent review remains pending.

The #566 output slice is committed as fcd11c0d with all five focused output
groups green under Clang/GCC/ASan+UBSan, plus closed-pipe and five emission
regressions. The full emission goal remains active.

Located expression bodies normalize into empty blocks retaining the original
expression and spans. Existing entry/result/signature logic, frame cleanup and
call-depth handling remain the owners of execution behavior. Only the
expression-body admission refusal was removed.

Validation: -Werror incremental build compiled changed lowering modules and
relinked CLI/tests. All three focused groups pass Clang, GCC 15, ASan/UBSan
and PUDU_EVAL=tree: eight explicit-output and counted-allocation programs,
three failure cases. Four focused lowering/refusal/closure/emission regression
groups pass. CLI imported expression-body output/status agree across native,
compiled and tree paths. Logs /tmp/pudu-expression-{clang,gcc,asan,tree}.log,
/tmp/pudu-expression-regressions.log and /tmp/pudu-expression-cli.log.
The original red E6001 probe is /tmp/pudu-expression-red.log.

The full release gate and workflows are unchanged. Full-suite/platform and
independent review evidence remain pending; no PR or promotion is claimed.

The expression-body slice is committed as e17d9987. Active callable parity work
continues in [[Native Named Callable Delivery]].

Exact next action: follow Native Named Callable Delivery for the current
callable dispatch repair and remaining completion work.

## Referenced by

[[handoffs/_MOC]] · [[Native Expression Bodies]]
