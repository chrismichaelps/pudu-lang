---
type: handoff
status: DONE
issue: 930
aliases: [Native iOS Capabilities Delivery]
---

# Native iOS Capabilities Delivery

Language Architect → Backend Engineer. Owns the four Std Mobile modules [[Std Mobile Gesture]], [[Std Mobile Scene]], [[Std Mobile Access]] and [[Std Mobile Feedback]]; the additions to [[Std Mobile Stream]], [[Std Mobile View]] and [[Std Mobile Host]]; the six host headers [[iOS Host Gesture]], [[iOS Host Feedback]], [[iOS Host Access]], [[iOS Host Scene]], [[iOS Host Motion]] and [[iOS Host Capability Test]]; the fixture [[Uses Mobile Capabilities]]; and the example [[Native Showcase Example]].

## Scope

Gestures, alerts and action sheets, haptics, progress and activity indicators, accessibility traits, hints and values, context menus, scene size and lifecycle, and animated groups on iOS. The UIKit inventory of what is covered and what is next is in [[Pudu Native iOS UI]], section "UIKit coverage".

Stacked on [[Native iOS Materials Delivery]] (#928).

## Evidence

- Compiler builds with no warnings; `pudu fmt --check` over packages, fixtures and examples is clean.
- Full Haskell fixture and property suite passes (210 properties).
- [[Uses Mobile Capabilities]] gives the same result interpreted and as a native host executable.
- Simulator run on Xcode 26 with the iOS 26.4 runtime: 19 checks pass, none skipped. They cover smoke, Counter, Form, List, Feed, Themed and Catalog on iPhone; three stream refusals; the same family runs on an iPad Pro 13-inch; glass on iOS 26.4 and the blur fallback on iOS 18.0; and the Showcase capability run (gestures with phases and values, size classes, lifecycle order, alert and action sheet choices, haptics, accessibility traits, hints and values, animated groups).
- [[UIKit Coverage Tests]] pass, and [[UIKit Coverage Inventory]] `--check` is clean against iPhoneSimulator26.5.
- [[iOS Simulator CI]] moves to a runner image whose Xcode meets the floor; the hosted macos-15 image's Xcode 16.4 refused the iOS target.
- A new device's first boot gets up to ten minutes; an iPad booting beside the phone took over four.

## Exact next action

None for #930. The iPhone Duo hinge and reserved regions wait for the iOS 27.1 SDK under the `fold-posture` ledger gate.

## Referenced by

[[handoffs/_MOC]] · [[Native iOS Materials Delivery]] · [[Pudu Native iOS UI]]
