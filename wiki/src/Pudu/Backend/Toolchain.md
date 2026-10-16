---
type: module
path: "@root/src/Pudu/Backend/Toolchain.hs"
fidelity: Active
domain: "[[Compilation Artifact]]"
subsystem: "[[Backend]]"
grammar: "[[grammar/haskell]]"
tags: [module, backend, toolchain]
aliases: [Backend Toolchain, Native Toolchain Adapter]
---

# Backend Toolchain

## Purpose and interface

The one module in the compiler that starts another process: it finds a C11
compiler, invokes it on generated source with a fixed flag policy, captures
its output under a bound, waits a bounded time, and publishes the resulting
executable atomically. Everything external and therefore unreliable is
isolated here; [[Backend Emit]] and [[Compiler Lower]] never see a process,
a path, or an environment variable.

```haskell
data ToolchainRequest = ToolchainRequest
  { toolchainSource :: !Text
  , toolchainOutput :: !FilePath
  }

data ToolchainFailure
  = ToolchainNotFound !Text
  | ToolchainInvocation !Text
  | ToolchainTimedOut !Int
  | ToolchainRejected !Text
  | ToolchainPublishFailed !Text

compileNative :: ToolchainRequest -> IO (Either ToolchainFailure Text)
```

A successful compile returns the compiler's captured output — normally empty
under the fixed policy, non-empty when the compiler had warnings to report.

## Algorithm and invariants

- Discovery: `PUDU_CC` when set (used as given), otherwise `cc` found on
  `PATH`. Nothing is installed, guessed, or searched for in package managers.
- The translation unit is written to a temporary `.c` beside the output; the
  compiler is invoked structurally — never through a shell — with exactly
  `-std=c11 -O2 -Wall -Wextra -o <temporary> <source>`.
- Standard output and error are drained concurrently and retained up to a
  fixed bound (64 KiB combined); beyond it, capture continues but only the
  head is kept, marked as truncated. The process is waited for with a bounded
  timeout (120 seconds by default, `PUDU_CC_TIMEOUT` seconds when set for
  testing).
- On success the temporary executable is renamed onto the output path — the
  same-filesystem rename that makes publication atomic — and both temporary
  files are removed. On any failure the output path is untouched and both
  temporaries are removed.
- Failure translation: missing compiler → `ToolchainNotFound`; start failure
  → `ToolchainInvocation`; expired wait → the process is terminated and
  `ToolchainTimedOut` carries the seconds; nonzero exit → `ToolchainRejected`
  with the captured output; rename failure → `ToolchainPublishFailed`.
- A successful compile with warnings still succeeds; the warnings are the
  success payload returned to the caller (tests assert the generated C is
  warning-free under the fixed policy).

## Negative Logic (Prohibited Paths)

- No shell interpolation, no globbing, no `sh -c`; arguments are passed as a
  list.
- No unbounded retention: a compiler that prints forever cannot exhaust the
  compiler's memory, and a compiler that never exits cannot hang the build.
- No partial publication: the output path never holds a truncated or
  half-written executable.
- No fallback compiler after a semantic compile failure; a rejection is
  reported, not retried elsewhere.
- No guessed flags: the policy is the four flags above, and nothing reads
  them from the environment.

## Dependencies and consumers

Requires `process`, `directory`, and `filepath` (all already library
dependencies) and [[Diagnostic Native]] through the caller for the message
vocabulary. Consumed by the `pudu build --native` path in [[Pudu CLI]];
described by [[Native Toolchain]]. This is the seam's only production
adapter, per [[ADR-0002-compiler-pipeline]].

## Grill Log

- **Q:** Why `PUDU_CC` at all? **A:** A developer with two compilers needs a
  way to say which one without the tool guessing, and the test suite needs to
  point the seam at scripted compilers to exercise `E6003`–`E6006`. It is an
  explicit, documented input — the alternative is magic discovery order.
  _Rejected:_ probing for `clang`/`gcc` by version and preference.
- **Q:** Why a fixed `-O2 -Wall -Wextra` policy rather than configurable
  flags? **A:** The artifact must be reproducible from the same program; flags
  that vary by environment make two builds of one program differ. A user who
  wants other flags has the generated C — emission is deterministic and
  documented — but the compiler's own build contract does not vary.
  _Rejected:_ a flags passthrough.
- **Q:** Why drain both pipes concurrently? **A:** A compiler that writes a
  lot of diagnostics while the parent reads only one stream will block on the
  other and appear to hang until the timeout; concurrent bounded drains turn
  that into an `E6005` with the real output. _Rejected:_ sequential reads
  after `waitForProcess`.
- **Q:** Why is the timeout override an environment variable and not a CLI
  flag? **A:** It exists for tests, not users; a flag would make the timeout
  part of the build contract, while the environment override is invisible
  unless deliberately set. _Rejected:_ a `--timeout` build option.

## Referenced by

[[src/Pudu/Backend/_MOC]] · [[src/Pudu/_MOC]] · [[Native Toolchain]] ·
[[Backend Emit]] · [[Compilation Artifact]] · [[Pudu CLI]] · [[Backend]] ·
[[ADR-0002-compiler-pipeline]]
