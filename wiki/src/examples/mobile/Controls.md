---
type: module
path: "@root/examples/mobile/Controls.pudu"
fidelity: Active
domain: "[[Pudu Native]]"
tags: [module, example, mobile, native, controls]
aliases: [Native Controls Example]
---

# Native Controls Example

## Purpose and interface

A program that exercises every value control on the iOS simulator. The root is a column with one control of each value kind and one label beside each. Each label shows the value its control's last event carried, so the screen always reads what the user last chose.

The labels, in order:
- `Volume: N` for a slider, from its VALUED event.
- `Count: N` for a stepper, from its VALUED event.
- `Size: NAME` for a segmented control with the labels Small, Medium and Large, from its VALUED event as the option index.
- `Fruit: NAME` for a wheel, from its VALUED event as the option index.
- `Moment: N` for a date picker, from its DATED event as whole seconds.
- `Notes: TEXT` for a text area, from its CHANGED event.
- `Search: TEXT` for a search field, from its CHANGED event.
- `Page: N` for a page indicator, from its VALUED event.
- `Color: N` for a color well, from its COLORED event as the RGBA value in decimal.

A symbol is shown beside the page indicator. It reports nothing, so its label is fixed.

The self-test is the controls check of [[pudu-ios-values]]. It runs with `PUDU_UI_CONTROLS_TEST` set, and drives each control once on every device family, iPhone and iPad. It expects the labels to read `Volume: 100`, `Count: 3`, `Size: Large`, `Fruit: Plum`, `Moment: 1000000000`, `Notes: Notes`, `Search: pudu`, `Page: 2` and `Color: 4286578943`.

The example uses [[Std Mobile Control]] for the control values, [[Std Mobile View]] for the `Control` wrapper, [[Std Mobile Events]] for the value events, and [[Std Mobile Host]]. Each value event replaces the stored value of its control before the next view is computed.

## Invariants

- Each label shows the last value its control reported. No label is computed from another control.
- The program never writes a value it did not receive from an event, except its initial values.

## Negative Logic

- No value is clamped in the example. Normalization is done by [[Std Mobile Control]] before the view is built.
- No timer, network call or foreign call is made by the program.

## Dependencies and consumers

Depends on [[Std Mobile Control]], [[Std Mobile View]], [[Std Mobile Events]] and [[Std Mobile Host]]. The host is [[iOS Host Adapter]] with [[pudu-ios-kinds]] and [[pudu-ios-values]]. Its fixture-level counterpart is [[Uses Mobile Controls]].

## Resolved Grill Log

- **Q:** Why show the last event value rather than the model? **A:** The self-test checks what the platform reports back, so each label must show the report, not a value the program assumed.
- **Q:** Why a fixed label for the symbol? **A:** A symbol reports nothing, so no event could change its label.

## Referenced by

[[src/examples/README]] · [[Uses Mobile Controls]] · [[Std Mobile Control]] · [[Native Value Controls Delivery]]
