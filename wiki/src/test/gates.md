---
type: module
path: "@root/test/gates.sh"
fidelity: Active
domain: "[[Testing]]"
subsystem: "[[architecture/DELIVERY]]"
tags: [module, test, release, gates]
aliases: [Repository Gates]
---

# Repository Gates

## Purpose and interface

[[Ark Layer Tests]] and [[Ark Layer Gate]] run before compilation to enforce engine import
architecture. Resolved Grill Log: architectural defects fail independently of runtime acceptance.

[[Ark Math Gate]] checks shipped Ark resolution, numerical regressions and wrong-width refusal
against the same freshly built optimized compiler. Resolved Grill Log: interpreted evidence
does not imply native engine performance.

Run the production release checks in a fixed order and report every failing gate: warning-free
optimized build, optimized full suite, Pudu formatting, diagnostic identities, API coverage, live
language-server sessions, documentation parity, the generated-project workflow, a real lint
command whose clean and failing exit statuses plus JSON output are checked outside the test runner,
and the peak memory of the file-streaming readers at ten times the input.

[[Lane Collection Gate]] checks that lane kernel buffers share collections rather than forcing
one per call.

## Governance and algorithm

[[Refresh Installation Test]] checks optimized installation orchestration before compiler builds.

[[Application Layer Tests]] and [[Application Layer Gate]] check the application import graph
before builds, rejecting cycles, missing identities and upward architectural dependencies.

Build products are removed before the warning gate so Cabal cannot answer from an older object. The
optimized executable path is resolved once and passed to behavioral scripts, including [[Generated
Project Gate]]. Independent checks continue after one fails; the script exits unsuccessfully when
any gate failed.

[[Streaming Residency Gate]] runs the file-streaming readers on a small and a ten-times-larger input
against the same binary and requires the same peak, with a buffered control that must grow.

[[Live Lint Gate]] runs against that same optimized binary and proves failing findings, stable JSON,
safe fixing, compiler acceptance, and a clean second lint without modifying repository source.
[[Diagnostic Code Gate]] audits the intentional reuse of compiler warning identities by lint policy
and output instead of allowing a second, incompatible lint-only code vocabulary.

[[Atomic Permission Gate]] exercises both public atomic-write APIs through that same binary,
checking process-umask creation modes, existing-file modes, private scratch files, symlink
replacement, failure output, and temporary-file cleanup on POSIX systems.

## Grill Log

- **Q:** Clean only the first `pudu-*` directory? **A:** No; clean every compiler
  and repository-test version root using `pudu-[0-9]*` and `pudu-tests-[0-9]*`.
  _Rationale:_ the broad first match can select tests and retain all compiler
  objects. Other dependency packages and source files remain untouched.
- **Q:** Change GHC options between build and test or invoke a different binary
  for documentation? **A:** No; test retains `-Werror` and documentation uses the
  already resolved optimized executable. _Rationale:_ changing configurations
  recompiles packages and breaks the gate's shared-binary evidence.

- **Q:** Stop after the first gate? **A:** No. _Rationale:_ one release run should expose every
  independent repair needed. _Rejected:_ fail-fast orchestration.
- **Q:** Let scaffold behavior live only in a manual command? **A:** No. _Rationale:_ onboarding is
  a production surface and distribution lookup differs outside the checkout. _Accepted:_ the
  generated-project workflow is mandatory in this gate.

Resolved Grill Log: every release-relevant boundary runs against the same freshly optimized binary,
including externally observable filesystem modes that portable permission booleans cannot prove.

## Referenced by

[[architecture/DELIVERY]] · [[Diagnostic Code Gate]] · [[Generated Project Gate]] · [[Streaming Residency Gate]] · [[Atomic Permission Gate]] · [[Pudu CLI]]

## Derive index contract (#458)

[[Derive Index Output Gate]] runs after documentation parity against the same freshly built executable.

Resolved Grill Log: local and integration delivery both exercise actual strategy output and public visibility.

## Swept movement (#720)

[[Ark Motion Gate]] validates query-driven sliding and typed refusals.
Resolved Grill Log: execute the focused gate beside the full compiler suite.
## Capsule cast contract (#716)

[[Ark Cast Gate]] runs with the optimized compiler. Resolved Grill Log: finite obstacle geometry
and explicit convergence failure require executable public-API coverage alongside the full suite.
## Character movement contract (#714)

[[Ark Character Gate]] runs against the optimized compiler. Resolved Grill Log: sweeps, corner
constraints and positioned type refusal must be exercised through the public library API.
## Qualified constructors (#717)

[[Qualified Variant Gate]] checks real aliased/imported constructor clients and positioned
negative cases. Resolved Grill Log: a silent error type is caught by wrong-result assertions.
