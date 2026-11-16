---
type: module
path: "@root/examples/mobile/Controls.pudu"
fidelity: Active
domain: "[[Pudu Native]]"
tags: [module, example, mobile, native]
aliases: [Native Controls Example]
---

# Native Controls Example

## Purpose and interface

A program that shows every value control on one screen: a slider, a stepper, segmented choices, a wheel, a date picker, a page control, a color well, a text area and a search field. Beside each control is a label that shows the last value the program received from it. The labels read:

| Label | Value shown after a run |
| --- | --- |
| `Slider: 30` | slider value |
| `Stepper: 6` | stepper value |
| `Segment: Week` | selected segment |
| `Wheel: Pear` | selected wheel row |
| `Date: 1000000000` | date picker seconds |
| `Pages: 3` | current page |
| `Color: ff8000ff` | color well, packed RGBA |
| `Notes: Notes` | text area text |
| `Search: pudu` | search text |

The example imports Std.Mobile.Control as `Input`. It starts with a symbol, then a label above each control. The model holds level, count, span, fruit, moment, notes, query, page and color. The screen is a scroll view holding one column.

The example uses [[Std Mobile Control]], [[Std Mobile View]], [[Std Mobile Decode]] and [[Std Mobile Host]].

The simulator run sets `PUDU_UI_CONTROLS_TEST`, which drives each control once through [[iOS Host Controls Test]]. The run is made on an iPhone and on an iPad.

## Invariants

- Each label shows the value the program received from its control. The program writes its state only through events.
- The labels are the labels of the screen in order, as the simulator run reads them.

## Negative Logic

- No clamping in the program. The slider and stepper show what the platform clamps to.
- No formatting of the date. The label shows the seconds as received.
- No real touch input in the run. The self-test drives the same queue that real input uses.

## Dependencies and consumers

Depends on [[Std Mobile Control]], [[Std Mobile View]], [[Std Mobile Decode]] and [[Std Mobile Host]], through the host headers [[iOS Host Values]], [[iOS Host Text]], [[iOS Host Kinds]] and [[iOS Host Controls Test]]. Run as described in [[iOS Simulator Run]]. Its controls are checked on the stream side by [[Uses Mobile Controls]].

## Resolved Grill Log

- None beyond the logs of [[Std Mobile Control]] and [[iOS Host Values]].

## Referenced by

[[iOS Simulator Run]] · [[Uses Mobile Controls]] · [[iOS Host Controls Test]] · [[Native iOS Controls Delivery]]
