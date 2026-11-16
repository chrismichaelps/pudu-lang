---
type: handoff
status: ACTIVE
issue: 934
aliases: [Native iOS Controls Delivery]
---

# Native iOS Controls Delivery

Language Architect → Backend Engineer. Owns the two Std Mobile modules [[Std Mobile Control]] and [[Std Mobile Decode]]; the changes to [[Std Mobile Stream]], [[Std Mobile View]] and [[Std Mobile Host]]; the host kind table split into [[iOS Host Kinds]]; the host headers [[iOS Host Values]], [[iOS Host Text]], [[iOS Host Controls Test]] and the changed [[iOS Host Adapter]], [[iOS Host Controls]] and [[iOS Host Events]]; the fixture [[Uses Mobile Controls]]; the example [[Native Controls Example]]; and the fixtures [[Uses Mobile View]], [[Uses Mobile List]] and [[Uses Mobile Capabilities]], whose decoder calls now go through [[Std Mobile Decode]].

## Scope

Value controls on iOS: slider, stepper, segmented control, wheel, date picker, text area, search field, system symbol, page control and color well. Each control has a stream encoding, a host factory and a decoded event. Event decoding moves from the view module to its own module so the view stays within its line budget. The host kind table moves to its own header for the same reason.

Stacked on [[Native iOS Capabilities Delivery]] (#930).

## Evidence

- Pending.

## Exact next action

Implement Std.Mobile.Control and Std.Mobile.Decode, then the host headers, then the fixture and simulator run.

## Referenced by

[[handoffs/_MOC]] · [[Native iOS Capabilities Delivery]]
