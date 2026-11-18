---
type: module
path: "@root/examples/mobile/Pages.pudu"
fidelity: Active
domain: "[[Pudu Native]]"
tags: [module, example, mobile, native, navigation]
aliases: [Native Pages Example]
---

# Native Pages Example

## Purpose and interface

A program that exercises the native navigation stack and one page sheet on the iOS simulator. The root route, Library, shows two counters and two buttons: Open pushes a new item page, and Show sheet presents a page sheet. An item page is a scroll body of one label, an Open button and forty lines of text. The sheet holds a label and a Close button.

The example uses [[Std Mobile Navigation]], [[Std Mobile View]] and [[Std Mobile Host]]. The model keeps the route ids on the stack, root first, the sheet's id, the next fresh id, and the counts of applied user pops and sheet dismissals.

The program applies each user report before it computes the next presentation. A `Popped` report is applied through `Navigation.kept`, so a stale report changes nothing. A `Dismissed` report clears the sheet only when it names the shown sheet. The stream from each `Navigation.update` is applied after the model is updated.

The self-test is the navigation check of [[pudu_ios_navigation.h]]. It runs with `PUDU_UI_NAVIGATION_TEST` set and `PUDU_UI_SELFTEST` unset. It taps Open, pops once through the back action, shows the sheet, dismisses it as the user, shows it again and closes it through its Close button.

Expected report lines, in order:

| Line | Source |
| --- | --- |
| `PUDU_NAV pushed` | host, the stack has two entries after Open |
| `PUDU_NAV popped once` | host, the root shows `Pops: 1` after the back action |
| `PUDU_NAV sheet shown` | host, the sheet is presented |
| `PUDU_NAV sheet dismissed once` | host, the root shows `Dismissals: 1` after the user dismissal |
| `PUDU_NAV sheet closed without echo` | host, the program's Close leaves `Dismissals: 1` unchanged |

The simulator run waits for the labels `Pops: 1` and `Dismissals: 1` and compares the five lines with [[iOS Simulator Run]].

## Invariants

- The root route id is the constant `HOME`, and it is never reused. Pushed routes and sheets take fresh ids from the model.
- A user pop changes the model only through `Navigation.kept`. A refused or stale pop leaves the stack as the program holds it.
- The sheet appears in the model only when the program shows it, and is removed from the model on its Close button or on a matching dismissal.

## Negative Logic

- No animation or transition is written by the program. UIKit owns the timing of pushes, pops and sheet transitions.
- No route is kept by the platform. A pop the program does not apply is resent as the full stack on the next update.
- No tab bar, deep link or other modal style is shown. Those remain open in [[Pudu Native iOS UI]].

## Dependencies and consumers

Depends on [[Std Mobile Navigation]], [[Std Mobile View]] and [[Std Mobile Host]]. The host is [[iOS Host Adapter]] with [[pudu_ios_navigation.h]]. Run as described in [[iOS Simulator Run]]. Its fixture-level counterpart is [[Uses Mobile Navigation]].

## Resolved Grill Log

- **Q:** Why does the program apply the user's pop rather than ignore it? **A:** The program owns the stack. Applying the pop through `kept` makes the next update send nothing, so the self-test shows that a completed user action changes state once and echoes nothing.
- **Q:** Why a scroll body for each item? **A:** A scroll body fills the page, so the page's layout and its scrolling are both exercised under the navigation bar.

## Referenced by

[[src/examples/README]] · [[iOS Simulator Run]] · [[Std Mobile Navigation]] · [[pudu_ios_navigation.h]] · [[Native iOS Navigation]] · [[Native iOS Navigation Delivery]]
