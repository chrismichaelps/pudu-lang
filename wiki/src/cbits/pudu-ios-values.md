---
type: module
path: "@root/cbits/pudu_ios_values.h"
fidelity: Active
tags: [module, host, ios, native, objective-c]
aliases: [iOS Host Values]
---

# iOS Host Values

## Purpose and interface

Private value controls of the iOS host, included once by [[iOS Host Adapter]]. The compiler stages it with the other private headers ([[Native Toolchain Host Sources]]). It owns the factories of the value controls, the setters that take bounds, options, counts and moments, each kind's number setter, and the events each control reports. The kind codes and the kind table that names these factories are in [[iOS Host Kinds]].

## Behavior

- Slider: a UISlider runs in step indexes 0 to (high - low) / step, so values stay exact whatever the range. A moved thumb settles on the nearest index and reports only when the stepped value changes. A drag across one step reports once. Reports VALUED with the stepped value.
- Stepper: a UIStepper with minimum, maximum and step from BOUNDS. Reports VALUED with its value.
- Segments: a UISegmentedControl. OPTIONS replaces its titles. VALUE selects an index. A person's choice reports VALUED with the index.
- Wheel: a UIPickerView subclass that is its own data source and delegate. OPTIONS sets its rows, VALUE selects a row, and a person's choice reports VALUED with the row index.
- Date: a UIDatePicker. MOMENT maps Day, Time and DayAndTime to the date, time and date-and-time modes. A change reports DATED with the floor of the seconds since the epoch.
- Pages: a UIPageControl. COUNT sets the number of pages; VALUE sets the current page. A person's change reports VALUED with the page.
- Well: a UIColorWell. VALUE sets the selected color from packed RGBA. A person's pick reports COLORED with the sRGB components rounded to 8 bits, alpha included.
- Each kind's number setter takes the VALUE word: the slider and stepper value as Int32 bits, the segment, wheel and page index, and the color as packed RGBA.
- BOUNDS sets the range and step of a slider or stepper. OPTIONS sets the labels of segments or a wheel. COUNT sets the page count of a page control. MOMENT sets the mode and the seconds of a date picker.

## Refusals

Each of the following is a stream defect. The host ends the process with a message naming the defect.

- BOUNDS with high less than low, or with a step of zero or less.
- BOUNDS on a kind that takes no bounds.
- OPTIONS with no labels, or on a kind that takes no options.
- COUNT on a node that is not a page control.
- MOMENT with an unknown mode, or on a node that is not a date picker.
- VALUE on a kind that takes no number.
- A segment or wheel index past the end of its options.

## Invariants

- The stepped slider value is the only value a slider reports. The unrounded thumb position never leaves the host.
- A reported value is the value the platform shows, so the program's view of the control matches the screen.
- The wheel's data source and delegate are the same object, so its rows are read from one place.

## Negative Logic

- No clamping in the host beyond the platform's own range. The slider and stepper take the bounds the program wrote.
- No formatting of dates. The seconds go to the platform as given.

## Dependencies and consumers

Depends on UIKit for the slider, stepper, segmented control, picker, date picker, page control and color well, and on [[iOS Host Events]] for the queue. Included by [[iOS Host Adapter]]. Its instructions are encoded by [[Std Mobile Control]] and [[Std Mobile Stream]]. Its events are decoded by [[Std Mobile Decode]]. Its self-test is run by [[iOS Host Controls Test]].

## Resolved Grill Log

- **Q:** Why does a slider report only a change of the stepped value? **A:** So a drag across one step reports once, and the program receives the values the platform shows rather than every pixel of motion.
- **Q:** Why does the date picker report whole seconds? **A:** Whole seconds since the epoch are independent of time zone and locale; the platform formats the date for the person.
- **Q:** Who clamps? **A:** The platform; the host reports the value it shows. See [[Std Mobile Control]].

## Referenced by

[[src/cbits/_MOC]] · [[iOS Host Adapter]] · [[Std Mobile Control]] · [[iOS Host Kinds]] · [[Native iOS Controls Delivery]]
