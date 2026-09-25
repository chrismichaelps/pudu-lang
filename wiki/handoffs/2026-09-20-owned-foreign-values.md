---
type: handoff
status: COMPLETE
date: 2026-09-20
issue: 227
tags: [handoff, ffi, ownership, abi, design]
aliases: [2026-09-20-owned-foreign-values]
---

# Owned Foreign Values Decision Handoff

## Objective

Close issue #227 as a language and ABI design decision without claiming unimplemented foreign syntax
or runtime behavior. [[ADR-0021-a-value-the-library-owns]] is the accepted implementation contract.

## Role transitions

1. **Language Architect:** accepts nested aggregate shape, target-derived natural C layout,
   declaration-only `Ptr`, per-result transfer modes, explicit identity paths, and
   generation-qualified claims.
2. **Independent Language Architect:** checks that the decision answers header-generation cost,
   pointer containment, address reuse, counted references, borrowed values, and nested ABI shape.
3. **Forensic Guardian:** checks the ADR, architecture roadmap, decision map, changelog, backlinks,
   and issue language agree without presenting unavailable syntax as implemented.

## Accepted boundary

- Authors write the opaque layout contract; a future header generator emits that same form.
- Nested aggregates remain nested. The target bridge derives natural C layout and call
  classification. Unsupported packing and special target classes are rejected.
- `Ptr` is an ABI scalar class inside an unreadable layout and never an expression type.
- Identity defaults to the whole value and may select unreadable layout paths. A live identity owns
  one generation; the same bits after release receive a fresh generation and cannot revive stale
  values.
- The opaque nominal type is non-`Copy` in every transfer mode. Borrowed values carry no release
  obligation and may be reused only through foreign calls that borrow them for the call.
- The accepted ADR does not make the syntax available. Parser, checker, runtime, native bridge,
  diagnostics, and conformance evidence must arrive as one separately tracked implementation slice.

## Exact next action

After the direct `dev` commit is pushed and issue #227 is closed with its commit reference, re-anchor
to issue #257 and the `Std.Html.Ssr` module mirror before changing implementation.

## Validation obligations

- Run repository vault/link gates and inspect the semantic delta.
- Confirm no implementation file or public grammar claims the accepted design is available.
- Preserve issue #227's three requested answers in the ADR Grill Log.
- Require the future implementation to prove nested-versus-flat ABI classification, move-only
  ownership, duplicate-live refusal, generation-safe identity reuse, borrowed teardown, counted
  references, declaration-only `Ptr`, and pointer-free resource identities.

## Completion evidence

- Independent architecture and forensic review found the nested-record grammar contradiction, a
  stale duplicate-ownership test, ambiguous scalar identity equality, borrowed-copy ambiguity,
  overlapping identity paths, and incomplete backlinks. The final pages resolve every finding.
- `git diff --check` passes.
- The warning-free optimized build passes when allowed to write Cabal's global log.
- The complete optimized test suite passes.
- The documentation-site parity gate passes with 155 indexed entries and 96,851 output bytes.
- No implementation file changes, and the accepted syntax remains explicitly unavailable.

## Referenced by

[[handoffs/_MOC]] · [[ADR-0021-a-value-the-library-owns]] · [[architecture/FFI-SELF-HOSTING]]
