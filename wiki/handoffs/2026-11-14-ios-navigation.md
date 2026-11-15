---
type: handoff
status: ACTIVE
issue: 920
aliases: [Native iOS Navigation Delivery]
---

# Native iOS Navigation Delivery

Language Architect → Backend Engineer. The architect owns the presentation
contract in [[Native iOS Navigation]]. Backend Engineer owns route validation and pop reduction in [[Std Mobile Navigation]], the stack snapshot in [[Std Mobile Stream]], and the regression in [[Uses Mobile View]]. UIKit stack ownership and completion handling are in [[iOS Host Navigation]]. Independent public-contract and vault-parity review
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

On iOS 26.4, the UIKit Back button displayed the root page and reported route 20 to 10 to the Pudu model. The simulator self-test observed the same payload once and the final root label.

The simulator suite also verified that an unchanged-stack completion emits no
event, and a Pudu-owned pop reaches the root without a native echo. A real
canceled edge gesture has not been verified.

The compiler-built sheet smoke runs both passed. The delegate path emitted
`SheetDismissed(40)` once with the root visible afterward, and the
Pudu-owned dismissal reached the same root without a native echo. The
simulator drives the dismissal completion. A real swipe remains unverified.

## Exact next action

Add a simulator regression for rapid sheet replacement followed by an old
dismissal callback, preserving the replacement in [[Native Sheets Example]].

## Referenced by

[[handoffs/_MOC]] · [[Native iOS Navigation]] · [[Pudu Native iOS UI]]
