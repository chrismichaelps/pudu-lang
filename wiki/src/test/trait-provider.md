---
type: module
path: "@root/test/trait-provider.mjs"
fidelity: Active
aliases: [Trait Provider Gate]
tags: [module, test, compiler]
---
# Trait Provider Gate

Use the real CLI to check and run explicit trait calls on known Int and record receivers with
different provider return types, in both declaration orders. Refuse wrong result annotations
with positioned E3001; keep plain receiver and type-qualified ambiguity at E3013. Type-check a
generic-bound control and execute exact nominal-provider text/integer results. Runtime generic
bound selection is separately reproduced and tracked in issue #743. Scratch files are isolated and
removed; compiler invocation time is bounded.

## Resolved Grill Log

- **Q:** Use a literal receiver only? **A:** No; deferred integer inference masked the bug.
- **Q:** Let both traits return Str? **A:** No; distinct result types expose the wrong scheme.
- **Q:** Check only acceptance? **A:** No; execute the selected methods and pin refusals too.

## Referenced by

[[Type Check Method]] · [[Type Check Call]] · [[Repository Gates]] · [[src/_MOC]]
