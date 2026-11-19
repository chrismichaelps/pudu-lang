---
type: module
path: "@root/examples/mobile/Refresh.pudu"
fidelity: Active
domain: "[[Pudu Native]]"
tags: [module, example, mobile, native, refresh]
aliases: [Native Refresh Example]
---

# Native Refresh Example

## Purpose and interface

A program that exercises pull to refresh and the safe-area insets on the iOS simulator. The root is a scroll viewport wrapped in a refreshing view. It shows a count of user pulls, whether the reported top safe-area inset is positive, and a Done button, followed by thirty numbered lines so the content can scroll.

The labels read `Pulls: N`, `Insets: top true` or `Insets: top false` once the scene has reported insets (`Insets: none` before that), and `Done`. The insets differ from one screen to another, so the label reports only whether the top inset keeps content clear of the status bar.

The program answers the first pull by refreshing: it sets the refreshing flag, and the indicator keeps spinning until Done clears the flag. It ignores every later pull, so the platform indicator must stop by itself at the next wait. The model keeps the pull count, the refreshing flag and the last reported insets.

The example uses [[Std Mobile View]] for the `Refreshing` wrapper, [[Std Mobile Events]] for the REFRESHED and INSETS events, [[Std Mobile Scene]] for `Insets`, and [[Std Mobile Host]]. Each `Refreshed` report is applied before the next view is computed, and each `SafeArea` report replaces the stored insets.

The self-test is the refresh check of [[pudu_ios_refresh.h]]. It runs with `PUDU_UI_REFRESH_TEST` set. It waits for the insets to be reported, pulls the scroll once and waits for the answer, taps Done when `Pulls: 1` shows, then pulls again and waits for the indicator to stop with `Pulls: 2` on screen.

## Invariants

- The program owns the refreshing flag. A pull changes the pull count only; the flag changes only through the program's view.
- Only the first pull is answered with refreshing. Later pulls are counted and ignored.
- The insets label reports the sign of the top inset only, so the same program passes on any screen.

## Negative Logic

- No content is loaded on a pull. No timer, network call or foreign call is made by the program.
- No indicator state is kept outside the model. The platform never sets the flag on the program's behalf.
- No safe area is applied by the program. The insets are read for their sign, and layout is left to [[Std Mobile View]].

## Dependencies and consumers

Depends on [[Std Mobile View]], [[Std Mobile Events]], [[Std Mobile Scene]] and [[Std Mobile Host]]. The host is [[iOS Host Adapter]] with [[pudu_ios_refresh.h]]. Run as described in [[iOS Simulator Run]]. Its fixture-level counterpart is [[Uses Mobile Refresh]].

## Resolved Grill Log

- **Q:** Who owns the refreshing state? **A:** The program; a pull only reports, and the indicator follows the program's value.
- **Q:** Why report the top inset as true or false rather than its value? **A:** Inset values differ by screen, so a label that printed them would make the simulator comparison depend on the device. The sign still shows that the status bar area was reported.

## Referenced by

[[src/examples/README]] · [[iOS Simulator Run]] · [[Std Mobile View]] · [[pudu_ios_refresh.h]] · [[Native iOS Refresh Delivery]]
