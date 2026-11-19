---
type: module
path: "@root/cbits/pudu_ios_controls.h"
fidelity: Active
tags: [module, host, ios, native, objective-c]
aliases: [iOS Host Controls]
---

# iOS Host Controls

## Purpose and interface

Private platform controls of the iOS host, included once by [[iOS Host Adapter]]. The compiler stages it with the other private headers ([[Native Toolchain Host Sources]]). It owns the factory of each control kind, the setters each kind accepts, the target object that turns control actions into queued events, and the self-test actions. The header never reads the view stream: the kind table that wires these factories into instructions lives in [[pudu-ios-kinds]].

The header holds the toggle, a title label beside a platform switch, and one factory per control kind: label, system button, vertical column, horizontal row, text field, toggle and list.

## Behavior

- A label uses the title-1 text style, which adjusts to the content size category.
- A button is a system button.
- A column is a vertical stack with spacing 16 and center alignment; a row is a horizontal stack with spacing 12 and center alignment.
- A text field is rounded and at least 220 points wide.
- A toggle is a title label beside a platform switch. Its tag and accessible name are carried by the switch.
- A list reports through its reached callback, which queues event kind 8 with the list's tag and the first visible index as the detail. Field focus is routed to the layout header [[iOS Host Layout]].
- The target object queues tapped, changed and switched events. Its actions carry the control's tag, its text and its state.
- Setters: text for label, button, field and toggle titles; hint for fields; state for toggles; accessible name for the control that carries it.
- Paint and style hooks: toggles take the ink role for their title; labels, fields and buttons are painted by [[iOS Host Theme]].
- Self-test actions: `fill` types into a field; `press` sends a tap to a button; the label report reads a label's text.

## Invariants

- Every platform call of this header runs on the thread that runs the program.
- Each factory returns a control of its kind and nothing else; no factory reads a tag's meaning.
- Each event queued by the target carries the tag of the control that sent it.

## Negative Logic

- No stream reading. This header never decodes an instruction and never looks up a node.
- No kind table. The mapping from kind code to factory and setter is in [[iOS Host Adapter]].
- No event constant is defined here; the kind values are in [[iOS Host Events]].
- No application logic and no retry.

## Dependencies and consumers

Depends on UIKit and on the event queue of [[iOS Host Events]]. Included by [[iOS Host Adapter]], which also includes [[iOS Host List]] for the list factory's cells. Staged by [[Backend Toolchain App]] and listed in [[Native Toolchain Host Sources]].

## Resolved Grill Log

- **Q:** Why move the controls out of the host? **A:** The host had reached its 500-line budget. Controls are a separate responsibility from reading the stream, and gesture and navigation work will grow them further. _Rejected:_ shrinking the host by deleting blank lines.

## Referenced by

[[src/cbits/_MOC]] · [[iOS Host Adapter]] · [[iOS Host Events]] · [[Native iOS Recycling Delivery]]
