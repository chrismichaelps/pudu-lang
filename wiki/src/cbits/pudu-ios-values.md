---
type: module
path: "@root/packages/pudu/v0.1/cbits/pudu_ios_values.h"
fidelity: Active
domain: "[[Pudu Native]]"
subsystem: "[[Native Mobile Targets]]"
tags: [module, host, ios, native, value, objective-c]
aliases: [iOS Host Values, pudu-ios-values]
---

# pudu-ios-values

## Purpose and interface

Private UIKit value controls of the iOS host, included once by [[iOS Host Adapter]]. The compiler stages it with the
other private headers ([[Native Toolchain Host Sources]]). It owns the factory, setters and report of each value
control: slider, stepper, segmented control, wheel, date picker, text area, search field, symbol, page indicator and
color well. It implements kinds 12 to 21 of [[Std Mobile Stream]] and the handlers of instructions BOUNDS (41), OPTIONS
(42), COUNT (43) and MOMENT (44). Its reports are queued through [[iOS Host Events]] as VALUED (21), COLORED (22),
DATED (23) and CHANGED (3) of [[Std Mobile Events]]. The kind table that names these factories is
[[pudu-ios-kinds]].

Controls:

| Class or object | UIKit base | Kind | Report |
| --- | --- | --- | --- |
| PuduSlider | UISlider, in step indexes | 12 | VALUED |
| UIStepper | UIStepper, in step indexes | 13 | VALUED |
| UISegmentedControl | segments are the option labels | 14 | VALUED, option index |
| PuduWheel | UIPickerView, one component | 15 | VALUED, option index |
| UIDatePicker | date, time or date and time | 16 | DATED |
| PuduTextArea | UITextView | 17 | CHANGED |
| UISearchTextField | shares the field target | 18 | CHANGED |
| UIImageView | system symbol image | 19 | none |
| UIPageControl | page indicator | 20 | VALUED, page index |
| PuduColorWell | UIColorWell | 21 | COLORED |

## Behavior

- PuduSlider keeps `low` and `step`, sets the platform's minimum to 0 and its maximum to `(high - low) / step`. A VALUE carries the snapped value; the slider converts it to its index as `(value - low) / step`, and
  reports VALUED with `low + index * step` only when the index changes.
- UIStepper uses the same index range as the slider and reports VALUED the same way.
- UISegmentedControl shows the option labels; a user choice reports VALUED with the chosen index.
- PuduWheel is the data source and the delegate of its picker. Each row is one option. A user selection reports VALUED
  with the row index.
- UIDatePicker maps Day to the date mode, Time to the time mode and DayAndTime to the date-and-time mode. A user change
  reports DATED with the whole seconds since the epoch as two words, high then low.
- PuduTextArea is the delegate of its text view. A text change reports CHANGED with the new text.
- UISearchTextField uses the target of the field kind in [[pudu_ios_controls.h]], so its changes take the same report path.
- UIImageView shows a system symbol, looked up by its name. A symbol reports nothing.
- UIPageControl takes its page count from COUNT and its current page from VALUE. A user page change reports VALUED with
  the page index.
- PuduColorWell takes its RGBA value from VALUE, red in the high byte. A user change reports COLORED with the RGBA value
  in the detail word.

Handlers:
- BOUNDS (41): node, low, high, step as signed words. Refused when high is below low, or when step is below one.
- OPTIONS (42): node, count, then each label as a length-prefixed UTF-8 text. Refused when the count is zero.
- COUNT (43): node, page count. Refused on a node that is not a page indicator.
- MOMENT (44): node, mode, seconds high word, seconds low word. Refused on a node that is not a date picker, and on a
  mode above 2.
- VALUE (29) on a kind without a number setter is refused. For a choosing kind, a VALUE index past the option count is
  refused.

Every refusal is a stream defect, reported through the same path as the refresh handler in [[pudu_ios_refresh.h]].

Self-test: `PUDU_UI_CONTROLS_TEST` drives each value kind once. The value is set through its instruction, then changed the
way a user would change it, and the report that comes back is checked. The test runs on the controls example of
[[Std Mobile Control]] on a simulator.

## Invariants

- A platform value is the host's form of the program's normalized value. The host performs no normalization of its own;
  it refuses what the program could not have produced.
- A program-set value is not reported. UIKit sends target actions only for user changes, so each report is a user change.
- A slider or stepper reports only when its index changes, so a continuous drag produces one event per step.
- A date is reported in whole seconds. Sub-second parts are dropped by the picker's value.
- Every call runs on the thread that runs the program, as every call of [[iOS Host Adapter]] does.

## Negative Logic

- No normalization. Bounds, options and indexes are normalized by the program in [[Std Mobile Control]].
- No report for a program-set value.
- No text transformation. CHANGED carries the text as UIKit reports it.
- No node creation or replacement. A variant or tag change is handled by the program, not here.
- No symbol report, because a symbol has no tag.

## Dependencies and consumers

Depends on UIKit, on [[iOS Host Events]] for the queue of VALUED, COLORED, DATED and CHANGED, on [[pudu_ios_nodes.h]] for
the node table, on [[pudu_ios_controls.h]] for the field target that search fields share, and on [[pudu-ios-kinds]] for
the table entries that name these factories and handlers. Included by [[iOS Host Adapter]]. Program side:
[[Std Mobile Control]], [[Std Mobile Stream]] and [[Std Mobile Events]].

## Resolved Grill Log

- **Q:** Why step indexes rather than values on the host? **A:** UISlider works in floating values. An index keeps every
  step exact, the program's integer is the only value on the stream, and the host computes `low + index * step` once
  for the report. _Rejected:_ floating values on the stream.
- **Q:** Why does the slider report only when the index changes? **A:** UISlider reports continuously while the user
  drags. Reporting on each index change sends one event per step rather than one per frame.
- **Q:** Why two words for seconds? **A:** Seconds since the epoch do not fit one 32-bit word. Two words, high then low,
  keep the 64-bit value exact. _Rejected:_ one word, which overflows in 2038.
- **Q:** Why does search share the field target? **A:** A search field reports text changes exactly as a text field
  does. One target keeps one report path.

## Referenced by

[[src/cbits/_MOC]] · [[iOS Host Adapter]] · [[pudu-ios-kinds]] · [[pudu_ios_controls.h]] · [[Std Mobile Control]] · [[Std Mobile Stream]] · [[Std Mobile Events]] · [[Native Value Controls Delivery]]
