---
type: handoff
status: ACTIVE
issue: 193
tags: [handoff, release, ownership, documentation, website]
---

# Places, Lending, and the Documentation Book

## Objective

Make `&mut`, `mut` fields, and array elements change what they name, and make the website's
documentation a complete, verified path from a first program to HTTP services. Work is committed
directly to `dev` at the user's explicit direction; no branch or PR is created.

## Ownership and roles

1. **Language Architect:** owns [[ADR-0022-lending-a-place]], the place rules in [[grammar/pudu]] and
   [[architecture/SEMANTICS]], and the release disposition in [[First Release Readiness]].
2. **Compiler Implementer:** owns [[Check Place]], [[Eval Place]], the lending hooks in
   [[Eval Call]] and [[Type Check Call]], and the formatter's statement-line rule in [[Format]].
3. **Website Implementer:** owns `website/docs/`, [[website View Docs]], [[website View Documentation]],
   [[website Domain Library]], and the stylesheet.
4. **Validation:** the full Cabal suite, the optimized `-Werror` build, the formatter gate, the
   diagnostic-code gate, the website suite, and running every documentation example.

The active role returns to **Language Architect** for the next critical readiness row.

## State

- `ed4894b` — documentation pages name their author, version, and source; the library index is a
  sectioned map; the catalogue is regenerated (173 modules, 3,456 declarations).
- `cf513ed` — chapter and page-list spacing; a fuller About page with labelled profile links.
- `3b7111b` — places and lending. Assignment stores into a `var`, a `mut` field, an array element, or
  `*r`; `&mut` arguments are handed back on every exit. `E3076`–`E3084` state every refusal, a `let`
  or parameter is no longer assignable, and the formatter places a statement opening with `*`, `-`,
  or `&` at its block's level. `UsesPlaces` evaluates 18 writes and `PlaceSpec` holds 28 cases; the
  full suite, the optimized `-Werror` build, and the formatter and diagnostic gates pass; 527 committed
  Pudu sources check unchanged.
- `41bf08f` — the documentation is twenty chapters in five parts; all 87 examples ran, and the
  website suite holds 100 assertions.

## Open

- Critical readiness rows remain for resource ownership and cancellation, package tooling (`lock`,
  `fetch`, `update`, `publish`), and large-input bounds evidence beyond files.
- A chapter on building a complete service with `Std.App` and `Std.Db` would follow the HTTP chapter.

## Next action

Read [[architecture/PACKAGES]] and the CLI command table, then write the mirrored page and Grill Log
for a `pudu lock` command that resolves a package's local dependencies and writes the lockfile the
architecture specifies.
