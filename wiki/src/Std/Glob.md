---
type: module
path: "@root/lib/Std/Glob.pudu"
fidelity: Active
domain: "[[Standard Library]]"
subsystem: "[[architecture/STDLIB]]"
tags: [module, stdlib, glob, paths]
aliases: [Std Glob]
---
# Std Glob
## Purpose
Match paths against the patterns people write into configuration: files to include, paths to
ignore, routes to match.
## Interface
Exports `matches`, `matchesAny`, `select`, `reject`, `isLiteral`, and `literalPrefix`.
## Governance and algorithm
The vocabulary is small and fixed: `?` matches one character and never a separator, `*` a run within
one segment, `**` whole segments including separators, `[abc]`/`[a-z]`/`[!abc]` one character of a
set, and `\` makes the next character ordinary. `**` followed by a separator also matches no segments,
so `**/x` matches a bare `x`; a set nobody closed is a literal `[`. The separator rule is what makes a
glob a path pattern: `src/*.pudu` and `src/**/*.pudu` are different patterns.

A pattern is read once into pieces, and a path is walked once while holding every piece position the
characters so far could have reached; each character advances them all together. No choice is retried,
so the work is the path's length times the pattern's, with no recursion. Trying each length a `*`
could take and backtracking made `*a*a*a*a*a*a*a*b` against forty `a`s run for over a minute and
recursed once per star; the walk answers it in 11 ms at -O2.

A `**` followed by a separator skips that separator only while it has matched nothing. The earlier
matcher advanced past the separator before trying longer matches, so the separator was silently
dropped: `**/b` matched `ab`, `a/**/b` matched `a/xb`, and a bare `**/` matched every path, which let
an ignore entry `**/node_modules` catch `my_node_modules`. A differential run over 980 pattern and
path pairs found exactly those cases and no others, each now `false`; no pair the earlier matcher
refused is accepted.
## Grill Log
- **Q:** Let `*` cross separators? **A:** No. _Rationale:_ there would be no way to name files in one
  directory only. _Accepted:_ `**` as the crossing form.
- **Q:** Match by backtracking over each length a star could take? **A:** No. _Rationale:_ patterns
  come from configuration and users, and a few stars against a near-miss path take exponential time.
  _Accepted:_ one walk over reachable pattern positions. _Rejected:_ a step budget, which would turn a
  slow match into a wrong answer.
- **Q:** Keep the earlier answer that `**/b` matches `ab`? **A:** No. _Rationale:_ `**` matches whole
  segments, and an ignore list naming a directory must not catch a name that only ends the same way.
  _Accepted:_ the separator is required unless `**` matched nothing.
## Referenced by
[[src/Std/_MOC]] · [[architecture/STDLIB]]
