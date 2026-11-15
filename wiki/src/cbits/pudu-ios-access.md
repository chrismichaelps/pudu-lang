---
type: module
path: "@root/cbits/pudu_ios_access.h"
fidelity: Active
tags: [module, host, ios, native, objective-c]
aliases: [iOS Host Access]
---

# iOS Host Access

## Purpose and interface

Private accessibility and context-menu implementation of the iOS host, included once by [[iOS Host Adapter]]. The compiler stages it with the other private headers ([[Native Toolchain Host Sources]]). It owns the TRAITS, ACCESS_HINT, ACCESS_VALUE and MENU instructions, the mapping of trait bits to UIKit traits, and the context menu a control carries. The header handles the instructions TRAITS (31) through MENU (34) of [[Std Mobile Stream]], and the event PICKED (13) of [[Std Mobile View]].

## Behavior

- TRAITS sets a control's accessibility traits from a mask. Bits 0 to 16 map to the UIKit traits in the order of [[Std Mobile Access]]. Bits 17 and 18, ToggleButton and SupportsZoom, are applied only on iOS 17 or later, through an availability check; on earlier systems they are ignored.
- ACCESS_HINT and ACCESS_VALUE set a control's accessibility hint and value to the text of the instruction.
- MENU attaches a context menu to a control. Each item is titled with its label. An item with role 2 is marked destructive. Role 0 and 1 are ordinary items.
- A menu item taken reports PICKED with the menu's tag and the item's index in the detail word.
- Attaching a menu again replaces its tag and items on the same control. The control keeps one menu interaction.
- The self-test reads the menu of a control with `pudu_menu_of` and picks an item as a person would.

## Invariants

- The control of an accessibility or menu instruction is the control the kind table names for its node, the same control that carries the tag.
- A menu's tag and items always match its last MENU instruction.

## Negative Logic

- No trait is inferred. The header applies the mask as given and never adds a trait the program did not send.
- No announcement. Live announcements and custom actions are not part of this header.
- Refusal: a trait mask with a bit at or above 19 ends the process with a message naming the defect. A menu item with a role of 3 or more ends it the same way.
- No hint or value is validated for length; the text is applied as written.

## Dependencies and consumers

Depends on UIKit for the traits and the context-menu interaction, and on the Objective-C runtime for the associated menu. Depends on [[iOS Host Events]] for the PICKED queue. Included by [[iOS Host Adapter]]. Its instructions are encoded by [[Std Mobile Stream]] from [[Std Mobile Access]] and [[Std Mobile Feedback]], and its self-test is run by [[iOS Host Capability Test]].

## Resolved Grill Log

- **Q:** Why does a menu report a choice rather than run a closure? **A:** The program owns every effect. A choice returns as an event to the one loop that handles the program, the same path a tap takes.
- **Q:** Why guard two traits on iOS 17? **A:** The traits are absent on earlier systems. An availability check keeps one stream valid on every version, where a missing trait would otherwise be a silent gap.

## Referenced by

[[src/cbits/_MOC]] · [[iOS Host Adapter]] · [[Std Mobile Access]] · [[Std Mobile Feedback]] · [[Native iOS Capabilities Delivery]]
