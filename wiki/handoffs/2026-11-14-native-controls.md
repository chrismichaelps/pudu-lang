---
type: handoff
status: COMPLETE
issue: 912
aliases: [Native Controls Delivery]
---

# Native Controls Delivery

Language Architect → Backend Engineer. Phase 2 of [[Pudu Native]]: rows, text fields, toggles and accessible names. Backend Engineer → Forensic Guardian review covers [[Std Mobile View]], [[Std Mobile Host]] and [[iOS Host Adapter]].

## Scope

The view stream gains rows, fields, toggles, names, the STATE, HINT and NAME codes and events with payloads. The iOS host dispatches its kinds and instructions through constant tables. The example [[Native Form Example]] exercises them.

## Evidence so far

A simulator run typed `Ada` and switched the toggle: the label read `Hello, Ada (subscribed)`; with Clear tapped it read `Hello, stranger`; status 0 both times.

## Exact next action

Continued in [[Native Keyed Lists Delivery]].

## Referenced by

[[handoffs/_MOC]] · [[Pudu Native]] · [[Native Form Example]] · [[Native First Light Delivery]] · [[Std Mobile View]] · [[Std Mobile Host]] · [[iOS Host Adapter]]
