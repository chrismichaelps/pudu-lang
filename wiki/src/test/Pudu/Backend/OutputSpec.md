---
type: module
path: "@root/test/Pudu/Backend/OutputSpec.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
aliases: [Native Output Tests]
---
# Native Output Tests

Export outputProperties and runOutputOracle. A child invocation of the test
binary enters runOutputOracle before runner buffering is changed, sets UTF-8
like the CLI, and evaluates actual checked Pudu through evaluateProgramEntryFolded.
The parent builds the same program natively and compares process bytes and
status through a C descriptor launcher.

## Resolved Grill Log

- Run handle failures in child processes, so retained failed buffers cannot
  contaminate the parent suite. GHC's own FD/handle behavior is the oracle.
- Test stdout and stderr separately with closed pipes, closed/read-only
  descriptors, a hung-up terminal where supported and /dev/full where present.
  Reset inherited SIGPIPE explicitly and cover default/ignored/blocked states.
- Capacity boundaries, Unicode and repeated writes run in one sequence so
  buffer state matters. Compare both tree and compiled evaluation.
- Missing compilers fail; unsupported signal platforms report their gap.
- Focused registration does not modify test/gates.sh or weaken full-suite
  aggregation. Successful output/capture and allocation tests live beside it.

## Referenced by

[[Repository Test Runner]] · [[Pudu Test Cabal Manifest]] · [[Native Output Results]]

## Missing inherited descriptor context (#566)

Resolved Grill Log: Extend the launcher with multiple missing-descriptor masks and verify Result outcomes through source exit statuses or a surviving standard stream. Do not rewrite oracle output.

## Bounded blocked-output observation

Resolved Grill Log: capture stdout/stderr in files and bound isolated process
waits. An intentionally blocked missing-descriptor case compares flushed
prefixes after termination as well as the blocked outcome. Ordinary cases
still require actual exit status and exact bytes; a timeout cannot become a
passing normal execution. Parent cleanup always terminates and reaps children.

## Entry output reporting (#566)

Resolved Grill Log: Register a separate entry-output parity property with large/boundary Str values and Result entries retaining prior failed output. Alias the isolated oracle binary as pudu to preserve the real CLI exception prefix. Require an actual exit, exact status and exact stream bytes for these probes.

Entry failure cases also include hung-up terminals and /dev/full on hosts
that provide it, plus multibyte text at the newline-reservation boundary.

## Fatal output readiness (#566)

Resolved Grill Log: Reporting probes include a source E7004 after prior output, failed stderr channels, and all missing-descriptor masks. Compare prefixes for expected blocking and require the same terminal outcomes, including SIGPIPE when fatal stderr output fails.

## First-class output builtins (#569)

Resolved Grill Log: Run failed-handle buffer sequences through direct and first-class output calls, comparing both evaluators and native bytes/status without changing the oracle.
