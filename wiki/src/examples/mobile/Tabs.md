---
type: module
path: "@root/examples/mobile/Tabs.pudu"
fidelity: Active
domain: "[[Pudu Native]]"
tags: [module, example, mobile, native, navigation, tabs]
aliases: [Tabs Example]
---

# Tabs Example

## Purpose and interface

A program with two tabs on a phone screen. The Home tab shows three counters, an Open button that pushes a Detail page inside the tab, and a Show sheet button that presents one page sheet over the bar. The Settings tab shows a single label. Labels report each answer, so a simulator or device run reads the same results the host reports.

The labels on the Home tab, in order:
- `Selected: 1`: the selected tab's id. The program sets it to 1 at start and to the id of each tab the person picks.
- `Pops: 1`: how many pops the person made inside a tab.
- `Dismissals: 1`: how many times the person dismissed the sheet.

The program uses [[Std Mobile Navigation]] for the tabs, [[Std Mobile View]] for the bodies and events, and [[Std Mobile Host]] for the apply and wait calls. The bar is mounted once when the screen is first built and updated after each event.

The example also has one refusal case the host must report: a TABS whose selected id names no tab is sent as a defect, and it is refused with `a selected tab that is not shown`.

## Simulator expectations

The iOS simulator run expects these labels: `Selected: 1`, `Pops: 1` and `Dismissals: 1`. The self-test of [[pudu-ios-tabs]] selects the Settings tab and back, which it checks as `Selected: 2` and then `Selected: 1`; it taps Open, pops once, shows the sheet and dismisses it. Its lines are `PUDU_TABS picked`, `PUDU_TABS pushed`, `PUDU_TABS popped once` and `PUDU_TABS sheet dismissed once`.

The Android run on an emulator or device has not been recorded. The next action is recorded in [[Native Tabs]].

## Invariants

- Each label is computed from the model, which changes only by a tab pick, a pop or a dismissal reported by the host, or by the program's own taps.
- The Home tab's label shows the selection even when the Settings tab is on top, because the first tab's root keeps its body.
- The program makes no decision about the platform answers; it counts them.

## Negative Logic

- No retry of a pop and no second sheet. The Show sheet button does nothing while a sheet is open.
- No timer. The answers arrive when the platform gives them.
- No change to the selection the program did not make. A pick changes the model only through the reported SELECTED.

## Dependencies and consumers

Depends on [[Std Mobile Navigation]], [[Std Mobile View]], [[Std Mobile Events]], [[Std Mobile Host]] and [[Std Env]]. Hosts: [[iOS Host Adapter]] with [[pudu-ios-tabs]]; and the Android host with [[PuduTabs]]. Its single-stack counterpart is [[Pages Example]], and its fixture is [[Uses Mobile Tabs]].

## Resolved Grill Log

- **Q:** Why a counter for pops and dismissals rather than only the current state? **A:** A counter shows that each report arrived once. A pop reported twice, or a dismissal the program never saw, would change the count, so the run can tell both from a correct result.
- **Q:** Why does the Detail page live inside the Home tab? **A:** A pushed page must stay under its own tab so that a pick of Settings and back returns the person to it. The check on the pop then covers the per-tab stack, not only the bar.
- **Q:** Why is the refusal a selected id with no tab? **A:** A selection that names no shown tab is the one bar fault the program can cause by a mistake in its model. Each other fault is checked by the fixture, and this one is the case the host must catch on the device.

## Referenced by

[[src/examples/_MOC]] · [[Uses Mobile Tabs]] · [[pudu-ios-tabs]] · [[PuduTabs]] · [[Native Tabs]] · [[NATIVE-MOBILE]]
