---
type: architecture
aliases: [Native Closed Pipe Semantics]
tags: [native, io, compatibility]
---
# Native Closed Pipe Semantics

## Observed failure and required behavior

A well-typed program discarding print's Result continues when stdout has no
reader under both ordinary evaluators. Before repair, native dies by SIGPIPE. A
continuation returns 7 in both evaluators but native exits by signal 13; a
later divide-by-zero still emits E7004/status 1 in both evaluators but native
dies before it; a unit entry exits zero in both evaluators but native dies.
Durable evidence: ~/.codex/tmp/pudu-504/pipe-probe-cases.json. This is a P1
observable divergence and blocks restoring the scalar ledger to Implemented.

## Process contract

The native C entry installs a nonterminating SIGPIPE handler where defined, once
before frame allocation/user code. Use standard signal.h and a named process_io
runtime part defining pudu_prepare_io. Select it from Frame program assembly
and call it at the beginning of C main for all entry result types. Do not reset
signal policy on each print or affect unrelated signals. On targets without
SIGPIPE, the initializer is a no-op. Rearm the handler using signal for C
implementations with one-shot disposition; a caught handler resets to default
on exec, unlike SIG_IGN. Match ordinary executable startup policy;
existing ignored IO Result effects then continue through fwrite/fflush failures.
No new syntax, diagnostic, source acceptance, IO Result representation or
interpreter change. This does not complete remaining owned-text/IO APIs.
Extended CLI probes show an essential distinction: closing stderr while a
runtime diagnostic is emitted terminates both evaluators by SIGPIPE, even when
the caller inherited SIG_IGN. Startup ignore alone incorrectly changes that to
status 1. A separate error_io/pudu_prepare_error_io part restores SIG_DFL only
on fatal diagnostic/memory-reporting paths, after frame cleanup and before
stderr writes. Restore the nonterminating handler after stderr flush and before
exit: C exit may retry a buffered failed stdout write, which must not replace
the intended status with SIGPIPE. A failed stderr write still terminates while
default disposition is active. Keep ordinary source execution on the handler.
A SIGPIPE-terminated diagnostic cannot rely on atexit for scalar-frame cleanup.

Primary runtime anchor: [GHC 9.14.1 signal setup/shutdown](https://github.com/ghc/ghc/blob/ghc-9.14.1-release/rts/posix/Signals.c), which installs an empty SIGPIPE handler and restores default disposition on shutdown. The exact stderr policy above is pinned by actual CLI probes, not inferred from that source alone.

Runtime revision becomes 6 for the process startup behavior change; later wide
frame ABI integration increments it again.

## Ownership and evidence

Backend Engineer owns Runtime and Emit.Frame startup selection/call plus their
mirrors. Test Engineer owns BrokenPipeSpec, registration and its mirror. Run
ordinary checked source through production lowering/emission and strict C11.
A separately compiled launcher redirects stdout to a pipe with no reader,
resets SIGPIPE to default and execs the generated executable; this prevents GHC's ignored
SIGPIPE disposition from masking the defect. Compare status/stderr to an ordinary
native run, pin expected source outputs/statuses and E7004, and include Int/unit
entries, stdout/stderr/both closure and inherited default/ignored/blocked dispositions.
Record a red reproduction before repair and green checks afterward.
The POSIX launcher is conditional on supported test hosts; unsupported signal
platforms need explicit platform evidence rather than a portability claim.
Re-run actual CLI tree/compiled/native pipe probes, sanitizer checks and full
gates. Only then restore the scalar row and regenerate the README. Independent
review and supported-platform evidence remain promotion requirements.

## Resolved Grill Log

- **Q:** Catch a signal after printf starts? **A:** No; install matching process policy before all user execution.
- **Q:** Suppress unhandled diagnostic pipe failure? **A:** No; restore default on fatal stderr paths after cleanup.
- **Q:** Ignore every signal or reset per print? **A:** No; only SIGPIPE at startup, preserving later explicit signal changes.
- **Q:** Trust Haskell-spawned child defaults? **A:** No; the test launcher explicitly restores default SIGPIPE first.
- **Q:** Return zero early on output failure? **A:** No; user continuation/entry status and later diagnostics still execute.

## Dependencies and consumers

[[Backend Runtime]] · [[Backend Frame Program]] · [[Native Broken Pipe Tests]] · [[Native Emission Coverage]]

## Referenced by

[[architecture/_MOC]] · [[Native Closed Pipe Delivery]]

## Extended observed matrix

108 actual CLI executions agree after the refined repair: three source cases,
four stream configurations (healthy/stdout/stderr/both), three inherited signal
states (default/ignored/blocked), and all three engines. Blocking SIGPIPE keeps
a failed diagnostic at status 1; do not unblock the caller's mask. Artifact:
~/.codex/tmp/pudu-505-pipe/cli-final-pipe-matrix.json. The clean run passed 18
gates and found one stale standard-header whitelist assertion. The corrected
signal.h allowance recompiled under -Werror; all 677 groups pass in the full-suite
rerun. Original failure and recheck logs remain separate. Independent review
and other supported-platform evidence remain pending.
