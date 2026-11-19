---
type: module
path: "@root/test/native-parity.mjs"
fidelity: Active
tags: [module, test, native, parity]
aliases: [Native Parity Gate]
---

# Native Parity Gate

## Purpose and interface

`node test/native-parity.mjs <path-to-pudu> [--jobs N] [--only <substring>]`

Every program under `test-fixtures/`, `examples/` and `website/playground/examples/`
that has a `main` and passes checking runs under `pudu run` and as the
`pudu build --native` executable, with the same environment and no input.
Standard output, standard error and exit status must agree. A native refusal of
such a program fails the gate.

`--jobs N` sets the number of programs run in parallel. `--only <substring>`
restricts the run to programs whose path contains the substring.

## Algorithm and invariants

- `Rejects*` fixtures and programs that fail `pudu check` are outside the
  comparison.
- A program the interpreter does not finish within 20 seconds is reported as
  skipped.
- A program runs from the directory its module path is relative to. A file
  whose name is not its module's, such as a numbered playground example, is
  staged under its module name in a temporary directory.
- `nondeterministic` names programs whose output varies between any two runs, each with its reason (elapsed time, frames or audio bytes counted in a time window, an ephemeral port); only their exit status is compared.
- `knownDifferences` is empty. It holds a program only while the issue that fixes its difference is open; an expected difference is reported as known, and a listed program that agrees fails the gate until its entry is removed.

## Dependencies and consumers

[[Native Emission Coverage]] records which constructs have native lowering. The
corpus this gate runs is shared with the fixture and example suites. It is also
run by the repository gates, see [[Repository Gates]].

## Resolved Grill Log

- **Q:** Compare whole programs instead of adding assertions? **A:** Yes. A
  native lowering that computes a different answer for a construct no fixture
  asserts passes every fixture, and the corpus already holds the programs
  (#956).
- **Q:** Compare standard error too? **A:** Yes. Runtime failures must stop at
  the same place with the same message.
- Known differences are listed with their issues rather than left failing, so the gate holds every other program now; the stale-entry failure keeps the list from outliving its fixes.

Link: [[Native Emission Coverage]]
