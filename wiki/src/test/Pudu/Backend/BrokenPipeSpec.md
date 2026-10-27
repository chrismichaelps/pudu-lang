---
type: module
path: "@root/test/Pudu/Backend/BrokenPipeSpec.hs"
fidelity: Active
aliases: [Native Broken Pipe Tests]
grammar: "[[grammar/haskell]]"
---
# Native Broken Pipe Tests

## Purpose and interface

Export brokenPipeProperties :: [(String, IO Property)]. Compile well-typed Pudu
through actual runCompile/lowerProgram/lowerFrames/emitProgram, then execute
strict C11 binaries with normal and closed-pipe stdout. Use existing test
text/process/temp dependencies. Honor PUDU_CC and fail a missing compiler.

## Algorithm and invariants

Exercise literal/Int/Bool/unit printing with an Int continuation returning 7,
a later E7004/status 1 and a unit entry/status 0. A separately compiled C launcher creates a pipe, closes its reader, duplicates
the write end onto stdout, resets SIGPIPE to default and execs the generated
executable. This reproduces shell startup
rather than inheriting GHC's ignored signal disposition. Normal output/status
are pinned; broken stdout preserves continuation and diagnostics. Extend the
launcher across stdout/stderr/both and inherited default/ignored/blocked dispositions.
A later diagnostic with stderr closed exits by signal 13 when unblocked, and
retains status 1 when the caller blocked SIGPIPE, as both actual evaluators do; no normal continuation is terminated merely for closed stderr.
On unsupported signal hosts report the explicit POSIX-test limitation. Actual
CLI probes compare both evaluators and native execution as separate evidence.

## Resolved Grill Log

- **Q:** A child inherits SIG_IGN and falsely passes? **A:** Reset it explicitly before generated startup.
- **Q:** Lose the later failure after ignoring output? **A:** Assert E7004 remains and its status/diagnostic equals normal execution.
- **Q:** Let startup suppression hide failed stderr reporting? **A:** No; distinguish ignored print results from fatal diagnostic writes.
- **Q:** Treat the regression as full IO completion? **A:** No; this repairs process policy only.

## Dependencies and consumers

[[Backend Frame Program]] · [[Backend Runtime]] · [[Repository Test Runner]] · [[Pudu Test Cabal Manifest]]

## Referenced by

[[src/_MOC]] · [[Backend Module Map]] · [[Native Closed Pipe Delivery]]

## Owned diagnostic payloads (#570)

Resolved Grill Log: extend the existing stdout/stderr/both and inherited
SIGPIPE matrix with dynamic E7001 and computed-help E7004 failures after
prior output. Each case names its expected diagnostic code explicitly; keep
all original status, bytes and signal-disposition assertions intact.
