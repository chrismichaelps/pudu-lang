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

Evaluation spec for collections, memory layout, flat maps, columnar vectors and the stdlib mobile fixtures. `testDataEvaluation` runs each fixture through the program runner and asserts the value it answers. The mobile entries cover the view stream, the list, the theme, the material, the capabilities, the navigation stack, and the refresh stream and insets.

The mobile entries checked by this spec:
- `test-fixtures/stdlib/UsesMobileView.pudu`: asserted to answer `30` ([[Uses Mobile View]]).
- `test-fixtures/stdlib/UsesMobileNavigation.pudu`: asserted to answer `19` ([[Uses Mobile Navigation]]).
- `test-fixtures/stdlib/UsesMobileRefresh.pudu`: asserted to answer `9`, the number of checks in the file ([[Uses Mobile Refresh]]).
- `test-fixtures/stdlib/UsesMobileResource.pudu`: asserted to answer `12`, the number of checks in the file ([[Uses Mobile Resource]]).
- `test-fixtures/stdlib/UsesMobileMemo.pudu`: asserted to answer `5`, the number of checks in the file ([[Uses Mobile Memo]]).
- `test-fixtures/stdlib/UsesMobileDevice.pudu`: asserted to answer `10`, the number of checks in the file ([[Uses Mobile Device]]).
- `test-fixtures/stdlib/UsesMobileLocation.pudu`: asserted to answer `9`, the number of checks in the file ([[Uses Mobile Location]]).
- `test-fixtures/stdlib/MemoRenderLambda.pudu`: asserted to be refused with exactly `E3103`, a memo render written as a lambda ([[Memo Render Lambda]]).
- `test-fixtures/stdlib/MemoRenderLocal.pudu`: asserted to be refused with exactly `E3103`, a memo render held by a local binding and passed through an import alias ([[Memo Render Local]]).
- `test-fixtures/stdlib/UsesMobileTheme.pudu`, `UsesMobileList.pudu`, `UsesMobileMaterial.pudu` and `UsesMobileCapabilities.pudu`, run by the same function; their expected values are in the file.

Other fixtures in the function cover lists, structures, ordered and relational maps, buffers, flat maps, columns, hash maps, database rows and the all-collection fixtures. They are listed in the file and are not described here.

## Invariants

- Each entry's result is compared with an exact expected value. A count is never a success by itself.
- The spec runs through the shared program runner, so it reads the same fixtures the interpreter reads.

## Negative Logic

- No simulator is needed. The mobile fixtures use only the pure interface of their modules.
- No foreign call is made by any mobile fixture checked here.

## Dependencies and consumers

Depends on the shared runner in `Pudu.Compiler.Program.Common` and on the fixtures above. The mobile fixtures' pages are [[Uses Mobile View]], [[Uses Mobile Navigation]] and [[Uses Mobile Refresh]].

## Resolved Grill Log

- **Q:** Why one spec for every mobile fixture? **A:** The fixtures share the same runner and the same exact-count contract, so one place states the expected count of each.

## Services (#989)

The fixture [[Uses Mobile Services]] (`test-fixtures/stdlib/UsesMobileServices.pudu`) expects 18 checks: the words of each of the eleven requests, the decoding of each of the seven events, and the refusal of a malformed POWERED and a malformed SENSED.

## Referenced by

[[Uses Mobile Memo]] · [[Uses Mobile Navigation]] · [[Uses Mobile Refresh]] · [[Uses Mobile View]] · [[Eval Data Tests]]
