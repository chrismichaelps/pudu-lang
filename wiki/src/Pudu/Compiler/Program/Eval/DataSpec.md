---
type: module
path: "@root/test/Pudu/Compiler/Program/Eval/DataSpec.hs"
fidelity: Active
domain: "[[Testing]]"
subsystem: "[[architecture/DELIVERY]]"
tags: [module, test, data, evaluation, mobile]
aliases: [Pudu Compiler Program Eval Data Spec]
---

# Pudu Compiler Program Eval Data Spec

## Purpose and interface

Evaluation spec for collections, memory layout, flat maps, columnar vectors and the stdlib mobile fixtures. `testDataEvaluation` runs each fixture through the program runner and asserts the value it answers. The mobile entries cover the view stream, the list, the theme, the material, the capabilities and the navigation stack.

The mobile entries checked by this spec:
- `test-fixtures/stdlib/UsesMobileView.pudu`: asserted to answer `30` ([[Uses Mobile View]]).
- `test-fixtures/stdlib/UsesMobileNavigation.pudu`: asserted to answer `19` ([[Uses Mobile Navigation]]).
- `test-fixtures/stdlib/UsesMobileTheme.pudu`, `UsesMobileList.pudu`, `UsesMobileMaterial.pudu` and `UsesMobileCapabilities.pudu`, run by the same function; their expected values are in the file.

Other fixtures in the function cover lists, structures, ordered and relational maps, buffers, flat maps, columns, hash maps, database rows and the all-collection fixtures. They are listed in the file and are not described here.

## Invariants

- Each entry's result is compared with an exact expected value. A count is never a success by itself.
- The spec runs through the shared program runner, so it reads the same fixtures the interpreter reads.

## Negative Logic

- No simulator is needed. The mobile fixtures use only the pure interface of their modules.
- No foreign call is made by any mobile fixture checked here.

## Dependencies and consumers

Depends on the shared runner in `Pudu.Compiler.Program.Common` and on the fixtures above. The mobile fixtures' pages are [[Uses Mobile View]] and [[Uses Mobile Navigation]].

## Resolved Grill Log

- **Q:** Why one spec for every mobile fixture? **A:** The fixtures share the same runner and the same exact-count contract, so one place states the expected count of each.

## Referenced by

[[Uses Mobile Navigation]] · [[Uses Mobile View]] · [[Eval Data Tests]]
