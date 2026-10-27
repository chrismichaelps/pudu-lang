---
type: module
path: "@root/src/Pudu/Backend/Runtime/Output.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
aliases: [Native Output Runtime]
---
# Native Output Runtime

Export outputRuntimeParts and outputRuntimeDependencies. The output_error
part defines pudu_output_write(stream, newline, text), returning empty Str
on success or an owned nonempty IOException rendering on failure. The
output buffer, raw-write retry/wait adapter, errno categories, and error
formatting follow [[Native Output Results]]. Text inputs are borrowed.
Temporary newline storage is released before formatting an error.

## Resolved Grill Log

- stdout and stderr keep separate static buffer bytes and published lengths.
- A failed flush does not publish a reset or append that GHC never published.
- OS writes retry EINTR, wait on EAGAIN, preserve partial-write order and
  return errno instead of terminating ordinary source execution.
- Shutdown retries pending bytes; it does not introduce a Pudu failure.
- The part follows text_allocate in catalogue order and declares only its
  actual prerequisites. No frontend/evaluator imports or runtime source files.

## Dependencies and consumers

[[Native Runtime]] · [[Native Runtime Dependencies]] · [[Backend Frame Values]]

## Referenced by

[[src/Pudu/Backend/_MOC]] · [[Native Output Results]]

## Blocking-descriptor readiness

Resolved Grill Log: standard descriptors use GHC's blocking FD policy. Poll
for writability before each raw write; a pipe reader is not made writable by
issuing a write that would immediately fail. Keep EINTR/EAGAIN retry and
pending-buffer publication unchanged.

## Entry output reporting (#566)

Resolved Grill Log: Add output_report/pudu_output_report for the entry builder and pinned top-handler failure format. It consumes borrowed rendered text, copies it into the existing buffer and leaves block-buffered data for shutdown. Its normal result is process status 0 or 1; EPIPE is silent.

## Minimal output catalogue closure

Resolved Grill Log: split shared state/error formatting (output_state),
source writes (output_error) and entry builders (output_report). An entry-only
program must not emit unused source-write/buffer functions, and a source-write
program must not pull in the entry exception reporter. Retain strict compiler
warnings rather than suppressing unused helpers.

## wait_writable (#636)

output_state depends on wait_writable, which its writer calls.
Resolved Grill Log: no output behaviour changes; only selection moved.
