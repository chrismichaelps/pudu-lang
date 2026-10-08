---
type: handoff
status: ACTIVE
issue: 459
tags: [documentation, stdlib]
---
# Derive Documentation Repair

Issue #459 owns only the primitive-implementation comments in [[Std Order]] and [[Std Num]],
their mirrors, navigation and changelog. Documentation Author resolves the explanation before
editing source; Tooling Engineer checks generated documentation, unchanged public identities,
formatting and lint. Work starts from freshly fetched development on
`feature/459-derive-documentation`. Preserve other work; no independent approval is claimed.
The wider application goal and issues #457 and #458 remain active.

Acceptance: remove both stale claims, explain primitive leaf capabilities accurately, retain all
executable source and public identities, check the actual generated comments and matching vault.
No new behavior tests are needed for a comment-only repair. Independent review remains pending.

Validation passes: generated documentation contains both primitive-leaf explanations and no
stale deriving claim; public API identity output is byte-equivalent after parsing; all non-doc
source lines are unchanged; formatting, lint, whitespace and application graph checks pass.
The full compatibility suite passed on the same executable and unchanged executable sources
in the preceding bundle repair. No new behavior tests or rebuild are warranted for these comments.

Exact next action: publish the validated #459 documentation repair for independent review.

## Referenced by

[[handoffs/_MOC]] · [[Std Order]] · [[Std Num]]
