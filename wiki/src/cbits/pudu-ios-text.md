---
type: module
path: "@root/cbits/pudu_ios_text.h"
fidelity: Active
tags: [module, host, ios, native, objective-c]
aliases: [iOS Host Text]
---

# iOS Host Text

## Purpose and interface

Private multi-line and search text controls of the iOS host, included once by [[iOS Host Adapter]]. The compiler stages it with the other private headers ([[Native Toolchain Host Sources]]). It owns the text area and the search field. The text area is new; the search field reuses the field setters and events of [[iOS Host Controls]].

## Behavior

- Text area: a UITextView with a secondary system background and rounded corners. It does not scroll, so the screen lays out its full height. It has a minimum size of 220 by 88 points, is its own delegate, and reports CHANGED with its text, as a text field does. It joins keyboard avoidance through `pudu_focus_field` in the layout header [[iOS Host Layout]].
- Search: a UISearchTextField. Its hint sets the placeholder, its text sets the field, and its edits report CHANGED with the tag and text, as a field does.
- Both controls take the TEXT, HINT and TAG instructions of [[Std Mobile Stream]] in the same way as the existing controls.

## Invariants

- A text area never scrolls inside its own bounds. Its height follows its text, so the enclosing viewport scrolls it.

## Negative Logic

- No event other than CHANGED is reported by this header.

## Dependencies and consumers

Depends on UIKit for the text view and the search field, and on [[iOS Host Events]] for the queue. Included by [[iOS Host Adapter]]. Its kinds are TEXT_AREA 17 and SEARCH 18 of [[Std Mobile Control]], named in [[iOS Host Kinds]]. Its events are decoded by [[Std Mobile Decode]], and its self-test is run by [[iOS Host Controls Test]].

## Resolved Grill Log

- None beyond the logs of [[iOS Host Values]] and [[Std Mobile Control]].

## Referenced by

[[src/cbits/_MOC]] · [[iOS Host Adapter]] · [[Std Mobile Control]] · [[Native iOS Controls Delivery]]
