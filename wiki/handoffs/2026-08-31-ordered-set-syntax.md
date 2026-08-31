---
type: handoff
status: ACTIVE
date: 2026-08-31
issue: 130
tags: [handoff, set, syntax]
---

# Ordered Set syntax — issue #130

## FMCF role transition and ownership

- **Architect:** fixed the semantic boundary in [[ADR-0013 Ordered Set Literals and Membership]]:
  the literal constructs the existing key-ordered Set, membership is Set-only, evaluation is
  left-to-right, and empty literals need context.
- **DNA Engineer:** owns the bounded implementation across tokens, syntax, parser, expansion,
  resolution, typing, evaluation, formatting, outline, fixtures, and tests on
  `feature/130-ordered-set-literals-membership`.
- **Language Architect reviewer:** must independently review syntax, precedence, inference, and
  evaluation order before merge.
- **Forensic Guardian:** must independently verify source/wiki parity and delivery evidence.

Agents are not alone in the repository. Preserve unrelated work and the root worktree's untracked
artifacts; do not revert changes outside this branch.

## Contract

- `#{a, b, c}` builds `Set[T]`; empty and trailing-comma forms are admitted.
- Every member expression runs left to right before duplicates collapse into key order.
- `candidate in values` is left-associative at comparison precedence and evaluates candidate first.
- v1 membership accepts only `Set[T]`.
- Context determines `#{}`; unresolved statement-boundary element types report `E3037`.
- Unorderable members retain `E7008`.
- `for pattern in expression` remains unambiguous.

## Owned files

The implementation may change only the corresponding mirrored compiler modules, their focused
tests and fixtures, this handoff, MOCs/backlinks, and `wiki/CHANGELOG.md`. Private local governance
inputs remain ignored and must never be staged.

## State

The implementation is complete across tokens, syntax, parser, expansion, resolution, typing,
evaluation, formatting, outline, fixtures and tests, and every mirrored page records the resolved
contract. The full gate list is green from a clean build directory: `-Werror` at `-O2`, the suite at
`-O2`, the formatter over every committed Pudu file, the diagnostic-code check at 104 codes, both
language-server tests, and the documentation-site contracts.

Each clause of the contract above is confirmed against a running program rather than only against
unit tests: key order and duplicate collapse, the trailing comma, an annotated empty literal,
membership answering `Bool` and composing at comparison precedence, members as arbitrary
expressions, literals as ordinary values passed and returned, text and tuple members, set operations
taking a literal directly, `for pattern in expression` still reading as a loop, and membership used
inside a loop body so both readings of `in` meet. The refusals hold too: `E3037` for an
unconstrained empty literal, `E3001` for a wrong member type, a non-`Set` container, and mixed
member types, and `E7008` at run time for an unorderable member.

## Exact next action

Independent review, which the implementer cannot supply. The Language Architect reviews syntax,
precedence, inference, and evaluation order; the Forensic Guardian verifies source and wiki parity
against this page and [[ADR-0013 Ordered Set Literals and Membership]]. Merge follows those two, not
the green gates.

## Referenced by

[[handoffs/_MOC]] · [[ADR-0013 Ordered Set Literals and Membership]] · [[grammar/pudu]]
