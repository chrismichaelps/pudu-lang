---
type: handoff
status: ACTIVE
issue: 920
aliases: [Native iOS Navigation Delivery]
---

# Native iOS Navigation Delivery

Language Architect → Backend Engineer. The architect owns the presentation
contract in [[Native iOS Navigation]]. Backend Engineer owns route validation and pop reduction in [[Std Mobile Navigation]], the stack snapshot in [[Std Mobile Stream]], and the regression in [[Uses Mobile View]]. Independent public-contract and vault-parity review
are pending.

## Scope

The design partition records route and sheet identity, completion ordering, and
the interaction with [[Pudu Native iOS UI]]. The implementation partitions
cover the native stack first, then page sheets. Tab bars, deep links, and
custom animations remain separate.

## Evidence

The mobile fixture returns 30 in the interpreter and as a compiled native
executable. It verifies duplicate identity refusal, valid and stale pops,
and the exact ordered snapshot with a multibyte title. Mounted stack cases
verify stable body identity, no-op updates, explicit reassertion, and retirement
after snapshot publication. FUI owns the cross-platform component API.

## Exact next action

Implement the UIKit NAVIGATION handler and completed-pop event bridge for the mounted stack snapshot.

## Referenced by

[[handoffs/_MOC]] · [[Native iOS Navigation]] · [[Pudu Native iOS UI]]
