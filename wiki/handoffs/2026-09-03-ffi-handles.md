---
type: handoff
status: IMPLEMENTATION
date: 2026-09-03
issue: 200
tags: [handoff, ffi, ownership, lsp]
aliases: [2026-09-03-ffi-handles]
---

# FFI Handles and C++ Boundary Handoff

## Role transition

- **Language Architect:** accepted the issue #200 boundary in [[ADR-0018 Calling a Library Written
  Elsewhere]]: block-local opaque owned handles, exact release signatures, runtime refusal before
  undefined behaviour, C++ only through `extern "C"`, and an explicit native-symbol mapping that
  preserves Pudu's local naming and editor identity.
- **Frontend/Semantic/Runtime/Tooling Implementer:** owns the issue #200 source, fixture, editor, and
  matching mirror changes. Existing uncommitted handle work is preserved and completed in place.
- **Independent Language Architect and Forensic Guardian:** review after focused and full gates; they
  do not edit the owned files during initial review.
- **Independent review result:** changes requested for qualified handle laundering, missing runtime
  cleanup, a concurrent liveness check/use race, and text-guessed LSP provenance. The implementer
  owns those corrections; the same reviewers re-audit afterward. All four are addressed and each
  carries a regression.
- **What the corrections turned up.** Closing the qualified-handle finding meant writing a
  cross-module binding program, and that program showed something larger: an imported declaration
  lost the restrictions it was declared under. An `unsafe` function became ordinary the moment it
  was imported, and a `comptime` one lost its transitive guarantee — so both boundaries held inside
  a module and dissolved at the import, which is where [[ADR-0018 Calling a Library Written
  Elsewhere]] recommends bindings live. Fixed in [[Type Check Import]] and [[Type Check Safety]],
  with [[Type Env]] carrying restrictions to every name a value is reached by.

## Owned boundary

Parser and syntax foreign declarations; resolution and foreign type checking; crossing and libffi
call storage; evaluator installation, runtime values, rendering, and foreign dispatch; documentation
index and LSP assertions; the test-only C++ fixture; matching vault pages and changelog.
The integration boundary also owns a headless Raylib fixture and its pinned shared-library workflow.
Review corrections add per-evaluation foreign ownership, full-call leases, deterministic teardown,
and resolver-identity-based hover/definition selection.

## Invariants

- One declared handle name is one nominal runtime kind; addresses never become Pudu integers.
- Only an `owned Handle by release` result creates an owned runtime handle.
- Null, unowned use, and repeated release are refused before entering foreign code.
- The release declaration takes exactly the produced handle and returns unit.
- C++ object layout, mangled names, and exceptions do not cross.
- A named third-party library must be proven through the platform loader, not only through symbols
  linked into the test executable; the Raylib proof must not require a display server.
- A qualified type can never become a block-local handle by sharing its basename.
- A declared restriction travels with the function rather than with the spelling that reached it:
  through a module qualifier, an import alias, a selected import, a variable, and a parameter.
- Teardown ends. What nobody is inside runs its declared release; what somebody is inside keeps its
  claim and is not freed under them.
- A handle stays leased from the last liveness decision until native code returns; release waits.
- Every still-live owned handle runs its declared release when the evaluator exits on any path.
- Hover and definition attach foreign provenance by resolved symbol identity, never by spelling.

## Exact next action

Obtain independent review of PR #201 and merge to `dev` on approval. Every P1 finding is resolved
with a regression, every gate passes locally and on both CI jobs, and the branch is mergeable and
clean. The review gate is the only thing outstanding, and the implementer cannot satisfy it.

## What the review corrections turned up beyond the findings

Closing the qualified-handle finding meant writing a cross-module binding program, and each thing
that program exposed led to the next:

1. **An imported declaration lost the restrictions it was declared under.** An `unsafe` function
   became ordinary on import; a `comptime` one lost its transitive guarantee. The boundary held
   inside a module and dissolved at the edge — the edge where [[ADR-0018 Calling a Library Written
   Elsewhere]] recommends bindings live.
2. **A restriction still travelled with the name rather than the value.** Stored in a variable or
   handed to a parameter, an unsafe function became an ordinary one. It is in the type now, and
   `unsafe(raw) fn(Int) -> Int` is a type a parameter can accept — without that half the feature
   would be closed by being unwritable.
3. **Teardown waited without bound.** A program whose foreign call never returned would hang on exit
   with nothing said.
4. **The compile-time rule was too strict, not too loose.** It refused every callee it could not
   name, which included every parameter, so higher-order compile-time code was unwritable — and it
   bought no guarantee, because an effect reached while folding is refused where it happens.

## The intermittent suite hang, found and fixed

The suite stopped responding on the Linux runner twice, in runs whose work was
otherwise identical to runs that finished in twenty seconds. It was not
flakiness in the infrastructure and not the foreign boundary: the generator for
the language server's JSON round-trip property recursed at a size that never
decreased, which made it a branching process with mean offspring of exactly one
— two chances in three of an internal node, times an average of one and a half
children. A critical process of that kind ends with probability one and has no
finite expected size, so nearly every value it produced was small and
occasionally one was astronomical.

Two things found it. Line-buffering the suite's output, added after the first
stall for exactly this purpose, named the test in the second one; the first
stall's log had ended mid-buffer and named nothing. And a standalone replica of
the generator failed to produce four thousand samples in forty seconds, which
turned a hypothesis into a measurement.

The depth halves at every step now, so the bound is structural rather than
statistical: at most 1 + 3 + 9 + 27 nodes. The first fix left half the samples
single scalars, which would have been a quiet loss of coverage, so the
generator is weighted towards containers — median nine nodes against the
previous median of one, and a ceiling of thirty-two.

## Known limitations, stated rather than implied

- **A trait or implementation member cannot be declared `unsafe`.** The parser refuses it, so there
  is no laundering route through a trait; what there is instead is no way to say that a trait method
  requires a capability. The arrangement to use is the one the rest of this design recommends
  anyway: an ordinary trait member whose implementation opens the region it needs, leaving callers
  of the trait needing nothing.
- **Capability sets match exactly, and there are no capability variables.** One wrapper cannot serve
  `raw` and `foreign` callers alike; it is written once per set. [[ADR-0009 Effects in the Type]]
  owns that question.
- **A pointer, a nullable pointer, and callbacks do not cross yet.** A record crosses by value, one level deep, declared beside the block that names it.
- **`comptime` is carried by name rather than by type**, which is sound because the fold refuses what
  it cannot evaluate, but means the early diagnostic covers declared functions only.

## Validation evidence

- Optimized `cabal build all --enable-optimization=2 --ghc-options='-Werror'`: pass.
- Optimized unfiltered `cabal test all --enable-optimization=2 --test-show-details=direct`: pass.
- Repository-wide Pudu formatter check: pass.
- Diagnostic-code uniqueness: 123 codes across 129 sources, pass.
- Real stdio LSP compatibility session: 14 frames, foreign handle and provenance assertions pass.
- Real stdio LSP robustness session: nine cases, seven contained and two correctly fatal framing
  failures, pass.
- Test-only C++11 fixture: create/read/release, imported binding module, null result, duplicate
  ownership, wrong handle, use after release, and double release all pass their exact assertions.
- Headless Raylib 6.0 integration on macOS: `GetRandomValue`, `MemAlloc`, and `MemFree` cross
  Homebrew's installed `libraylib.6.0.0.dylib`, return exit status zero, and the release uses the
  same checked opaque-handle path as the C++ fixture. A pinned Linux shared-library workflow runs
  for FFI-affecting pull requests, weekly, and on manual dispatch.
- Native-symbol mapping: the ordinary C fixture calls local `absolute` through symbol `abs`; the
  real LSP sessions infer and expose the mapped local function, and empty symbol text reports
  `E3068` at the declaration.

## Referenced by

[[handoffs/_MOC]] · [[ADR-0018 Calling a Library Written Elsewhere]]
