---
type: handoff
tags: [handoff, stdlib, json]
---

# JSON String Decoding Handoff

Issue #154 makes `Std.Json`'s string boundary linear and JSON-conformant without changing its
public types or functions. The work is intentionally narrower than the proposed Haskell-inspired
standard-library expansion; new public modules require separate contracts and reviewable PRs.

## FMCF role transition and ownership

The **Standard-Library Boundary Engineer** owns `lib/Std/Json.pudu`, one focused standard-library
fixture, its program-evaluation assertion, [[Std Json]], this handoff, the handoff map, and
`wiki/CHANGELOG.md`. Other compiler, runtime, LSP, and standard-library work is preserved.

After implementation, a **Language Architect** reviews JSON semantics and the absence of an
accidental public API change. An independent **Forensic Guardian** reviews implementation/wiki
parity and validation evidence. Neither reviewer edits the owned files.

## Decisions

- `readText` is a cursor loop, not an escape parser.
- A private helper decodes one escape and returns `(text, nextIndex)` through the existing typed
  `JsonError` result.
- Unknown escapes are rejected; backspace and form feed are decoded and encoded correctly.
- UTF-16 surrogate pairs in `\u` notation compose to one Pudu scalar; isolated surrogates fail.
- No new export or effect is introduced.

## Grill Log

- **Q:** Is permissive escape handling a compatibility promise? **A:** No. It contradicted JSON's
  grammar and allowed a misspelling to become silent data corruption. _Rejected:_ preserving `\q`
  as `q` merely because the implementation happened to do so.
- **Q:** Should this PR also add `Std.Tree`, `Std.Validation`, or `Std.These`? **A:** No. Each public
  data structure needs its own purpose, algebra, examples, and review boundary. _Rejected:_ a mixed
  “more Haskell” library bundle whose individual contracts cannot be reviewed.
- **Q:** Does flattening mean moving the same nesting into another function? **A:** No. The escape
  dispatcher has one flat decision, Unicode validation uses early typed exits, and the main loop
  has no nested `match` or conditional ladder. _Rejected:_ cosmetic extraction without reducing
  control-flow depth.

## Exact next action

~~Implement the mirror contract in `Std.Json`, add the executable escape fixture and program-test
assertion, then run focused O0/O2 checks and the full regression gate before independent review.~~

~~Obtain independent Language Architect and Forensic Guardian review.~~ Both returned CLEAR. The
Forensic Guardian found one canonical-encoding mismatch before clearing: the generic control path
preceded named newline, carriage-return, and tab escapes. The dispatcher order and fixture were
corrected, and the final review verified parity. The Language Architect verified escape grammar,
cursor positions, surrogate composition, typed failure, API stability, and the constrained
Haskell-derived roadmap; its suggested non-low-surrogate regression case was added.

Commit the reviewed slice, push it, open the issue #154 PR against `dev`, wait for CI, and merge it.

Validation already run:

- `pudu fmt --check` across every `lib/` and `test-fixtures/` Pudu source.
- `pudu check test-fixtures/stdlib/UsesJsonStrings.pudu`: no diagnostics.
- `pudu run test-fixtures/stdlib/UsesJsonStrings.pudu`: exit status 0.
- `cabal test all --test-show-details=direct`: pass under O0.
- `cabal test all --enable-optimization=2 --test-show-details=direct`: pass under O2.
- `git diff --check`: pass.

## Referenced by

[[handoffs/_MOC]] · [[Std Json]] · [[architecture/STDLIB]]
