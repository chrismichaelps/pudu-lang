---
type: handoff
status: ACTIVE
issue: 920
aliases: [Native iOS Navigation Delivery]
---

# Native iOS Navigation Delivery

Backend Engineer implementing; Language Architect and Forensic Guardian review pending.
The architect owns the presentation contract in [[Native iOS Navigation]]. Implementation will own the mobile
route representation, its stream and event contracts, and UIKit presentation
and completion handling. Independent public-contract and vault-parity review
are pending.

## Scope

The design partition records route and sheet identity, completion ordering, and
the interaction with [[Pudu Native iOS UI]]. The implementation partitions
cover the native stack first, then page sheets. Tab bars, deep links, and
custom animations remain separate.

## Exact next action

Validate the native stack and page sheet on the simulator with PUDU_UI_NAVIGATION_TEST, then open the PR to dev.

## Referenced by

[[handoffs/_MOC]] · [[Native iOS Navigation]] · [[Pudu Native iOS UI]]
