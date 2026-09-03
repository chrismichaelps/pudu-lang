---
type: handoff
status: REVIEW
date: 2026-09-03
issue: 200
tags: [handoff, ffi, ownership, lsp]
aliases: [2026-09-03-ffi-handles]
---

# FFI Handles and C++ Boundary Handoff

## Role transition

- **Language Architect:** accepted the issue #200 boundary in [[ADR-0018 Calling a Library Written
  Elsewhere]]: block-local opaque owned handles, exact release signatures, runtime refusal before
  undefined behaviour, and C++ only through `extern "C"`.
- **Frontend/Semantic/Runtime/Tooling Implementer:** owns the issue #200 source, fixture, editor, and
  matching mirror changes. Existing uncommitted handle work is preserved and completed in place.
- **Independent Language Architect and Forensic Guardian:** review after focused and full gates; they
  do not edit the owned files during initial review.

## Owned boundary

Parser and syntax foreign declarations; resolution and foreign type checking; crossing and libffi
call storage; evaluator installation, runtime values, rendering, and foreign dispatch; documentation
index and LSP assertions; the test-only C++ fixture; matching vault pages and changelog.

## Invariants

- One declared handle name is one nominal runtime kind; addresses never become Pudu integers.
- Only an `owned Handle by release` result creates an owned runtime handle.
- Null, unowned use, and repeated release are refused before entering foreign code.
- The release declaration takes exactly the produced handle and returns unit.
- C++ object layout, mangled names, and exceptions do not cross.

## Exact next action

Obtain independent Language Architect and Forensic Guardian review on the issue #200 PR, then merge
to `dev` after required checks succeed.

## Validation evidence

- Optimized `cabal build all --enable-optimization=2 --ghc-options='-Werror'`: pass.
- Optimized unfiltered `cabal test all --enable-optimization=2 --test-show-details=direct`: pass.
- Repository-wide Pudu formatter check: pass.
- Diagnostic-code uniqueness: 121 codes across 126 sources, pass.
- Real stdio LSP compatibility session: 14 frames, foreign handle and provenance assertions pass.
- Real stdio LSP robustness session: nine cases, seven contained and two correctly fatal framing
  failures, pass.
- Test-only C++11 fixture: create/read/release, imported binding module, null result, duplicate
  ownership, wrong handle, use after release, and double release all pass their exact assertions.

## Referenced by

[[handoffs/_MOC]] · [[ADR-0018 Calling a Library Written Elsewhere]]
