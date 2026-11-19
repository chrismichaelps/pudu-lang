---
type: handoff
status: ACTIVE
issue: 962
aliases: [Native iOS Refresh Delivery]
---

# Native iOS Refresh Delivery

Backend Engineer implementing; Language Architect and Forensic Guardian review pending.
The architect owns the refresh contract in [[Std Mobile View]] and its spellings in [[Std Mobile Stream]] and
[[Std Mobile Events]]. Implementation owns the refresh control in [[pudu_ios_refresh.h]], the insets report in
[[iOS Host Scene]], and the example and fixture pages listed in the vault. Independent public-contract and
vault-parity review are pending.

## Scope

This slice adds pull to refresh to scroll and list nodes and reports the safe-area insets as values. The program
owns the refreshing state; a pull only reports. The slice is stacked on the navigation branch, so it shares the
stream codes and the host instruction table of [[Native iOS Navigation Delivery]]. Tab bars, deep links and custom
refresh indicators remain separate.

## Exact next action

Validate on the simulator with PUDU_UI_REFRESH_TEST, then open the PR to dev after #961 merges.

## Referenced by

[[handoffs/_MOC]] · [[Std Mobile View]] · [[Native iOS Navigation Delivery]] · [[pudu_ios_refresh.h]]
