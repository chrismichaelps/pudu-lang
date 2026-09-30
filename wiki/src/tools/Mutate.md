---
type: script
path: "@root/tools/Mutate.pudu"
fidelity: Active
tags: [tooling, testing, mutation, stdlib]
aliases: [Std Mutation Harness]
---
# Std Mutation Harness

An internal program that measures how much of the standard library its fixtures actually assert. It
is run with `pudu run` from the repository root and is not part of the command line.

- Each mutant is one operator change in one `packages/pudu/v0.1/lib/Std/` file: a comparison, a
  boolean connective or literal, a `+ 1`/`- 1`, or a removed `!`. Comments, string and character
  literals, and imports are never mutated.
- The oracle for a file is every `test-fixtures/stdlib/` program that imports its module by name.
  Their unmutated status and output are the baseline; a mutant is killed when any fixture answers
  differently or runs past sixty seconds, invalid when `pudu check` rejects it, and survived
  otherwise. The file is restored after every mutant.
- A file no fixture imports is reported as `uncovered`: a module the fixtures cannot see.
- Flags: `--file PATH`, `--dir PATH` (default the whole Std tree), `--every N` and `--offset K` to
  sample, `--threshold P` to exit `1` below a score, and `--dry-run` to list mutants and uncovered
  files without running anything.
- `PUDU_LIB` must name this tree's library so the fixtures read the mutated file; `PUDU_BIN` names
  the compiler, `pudu` by default.

Resolved Grill Log:
- **Q:** Add the harness as a `pudu` subcommand? **A:** No. _Rationale:_ it rewrites library sources
  in place and is an audit instrument, not a user feature. _Rejected:_ a CLI command.
- **Q:** Kill a mutant only by a failing exit status? **A:** No. _Rationale:_ stdlib fixtures answer
  an assertion count, so a changed count or changed output is the failure. _Rejected:_ status-only
  verdicts, which let most mutants survive.

## Referenced by
[[src/_MOC]] · [[Std Net]] · [[Std Url]]
