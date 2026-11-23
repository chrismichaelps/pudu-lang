---
type: module
path: "@root/test-fixtures/stdlib/UsesMobileTabs.pudu"
fidelity: Active
tags: [module, fixture, stdlib, mobile, native, navigation, tabs]
aliases: [Uses Mobile Tabs]
---

# Uses Mobile Tabs

## Purpose and interface

Stdlib fixture for the tab bar: its stream in [[Std Mobile Stream]] and [[Std Mobile Navigation]], and its reports in [[Std Mobile Events]]. Its entry `main` builds two tabs, Home and Settings, and checks the TABS words, the change detection of `updateTabs` and `observeTabs`, and the decoding of SELECTED. It answers the number of checks that held. The data spec `test/Pudu/Compiler/Program/Eval/DataSpec.hs` asserts that count, which is `10`.

Checks, one per `if` of `main`:
1. TABS with one tab, one page and no sheet writes 47 bytes: the code 54, the count 1, the tab's id, title, symbol and page count, the page's route id, body node and title, then the selection 1 and the sheet flag 0.
2. TABS with the same tab and a sheet of id 30 and body node 5 writes 55 bytes, and the sheet flag, id and body node follow the selection.
3. An unchanged bar, passed to `updateTabs` against the bar it mounted, writes nothing.
4. A pick of tab 2 reported as `Selected(2)` and observed by `observeTabs` writes nothing on the next update for the same bar, because the platform already shows that selection.
5. A bar that selects tab 2 without an observed pick writes a stream, and an observed pick of an unknown tab 9 is ignored, so the next update for tab 2 writes a stream.
6. An observed pop inside a tab, `Popped(11, 10)`, ends only the popped page's body. The next update writes a stream whose first word is the popped route id 11.
7. A stale pop, `Popped(99, 10)`, is ignored, so the next update writes at least as much as the observed pop did.
8. An observed dismissal of sheet 30 ends only the sheet's body. The next update writes a stream whose first word is 11.
9. Removing tab 2 from the bar resends the bar, and the stream is non-empty.
10. SELECTED with tab id 2 as its tag decodes to `Selected(2)`.

Each check adds one to the count; a failing check leaves the count short of `10`.

## Invariants

- Each check compares an exact word count, byte length or decoded value, so a wrong code, tag, length or order fails the check.
- The fixture makes no foreign call and starts no host. It runs interpreted and as native C11 code, and both must agree.

## Negative Logic

- No platform call. Whether the tab bar shows the picked tab, pops inside a tab or dismisses a sheet is checked by the simulator and device runs of [[Tabs Example]], not here.
- No refusal is checked here. A tab with no pages, a repeated id, an unknown selection and a sheet sharing a route id are refused by the host.

## Dependencies and consumers

Depends on [[Std Mobile Stream]], [[Std Mobile Navigation]], [[Std Mobile Events]], [[Std Mobile View]] and `Std.ByteOrder` for the word reads. Its checks mirror the contract that [[pudu-ios-tabs]] and [[PuduTabs]] rely on. Its single-stack counterpart is [[Uses Mobile Navigation]].

## Resolved Grill Log

- **Q:** Why check exact byte lengths rather than only that a stream is written? **A:** A wrong tab id or a swapped page count keeps the shape of the stream. Only the exact words and the total length catch it, as in [[Uses Mobile System]].
- **Q:** Why is a pick the program already shows a no-op? **A:** A pick is observed into the model first. An update for the same bar then has nothing to tell the platform, so it writes nothing and does not flicker the bar.
- **Q:** Why is an unknown pick ignored rather than shown? **A:** The platform reports only the tabs it shows. A tab id outside the bar is a stale report, and it must not change the selection the program holds.
- **Q:** Why check the removal as a resend rather than the exact words? **A:** Removal ends a tab's pages through their own instructions. The check asserts that the bar is sent again, and the exact tree words are covered by the navigation fixture.

## Referenced by

[[src/_MOC]] · [[Std Mobile Navigation]] · [[Std Mobile Stream]] · [[Std Mobile Events]] · [[pudu-ios-tabs]] · [[Tabs Example]] · [[Native Tabs]] · [[NATIVE-MOBILE]]
