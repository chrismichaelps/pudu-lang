---
type: module
path: "@root/cbits/pudu_ios_motion.h"
fidelity: Active
tags: [module, host, ios, native, objective-c]
aliases: [iOS Host Motion]
---

# iOS Host Motion

## Purpose and interface

Private motion implementation of the iOS host, included once by [[iOS Host Adapter]]. The compiler stages it with the other private headers ([[Native Toolchain Host Sources]]). It owns the ANIMATE instruction, the marking of animated groups, and the single animation the host runs at the end of a commit. The header handles ANIMATE (35) of [[Std Mobile Stream]].

## Behavior

- ANIMATE marks a group as animated, or clears the mark. The group is a column or a list that the program placed with `Animated`.
- A placement or removal under a marked group notes that the commit changed the group's layout.
- At the end of every commit the host applies one animation to the surface, if an animated group changed in that commit. The animation is a spring over 0.35 seconds with damping 0.85, and it begins from the current state.
- With Reduce Motion on, the same layout change is applied at once, without animation.
- Each run of the animation is counted, so the self-test can report that an animated commit ran.

## Invariants

- A commit runs at most one animation, however many groups changed.
- An unmarked group never animates, even when its children change.
- The pending mark is cleared when the commit ends, whether or not an animation ran.

## Negative Logic

- No animation per instruction. Placements in one commit share one spring, so the ordered placements stay consistent with one another.
- No custom curve, duration or interaction. The values are the platform's spring defaults with the constants above.
- No animation of a commit that changed no animated group.
- No refusal. ANIMATE with any flag is accepted; a flag of zero clears the mark.

## Dependencies and consumers

Depends on UIKit for the spring animation and the Reduce Motion setting, and on the Objective-C runtime for the group mark. Included by [[iOS Host Adapter]]. Its instruction is encoded by [[Std Mobile Stream]] from [[Std Mobile View]]'s `Animated` wrapper, and its self-test is run by [[iOS Host Capability Test]].

## Resolved Grill Log

- **Q:** Why animate per commit rather than per instruction? **A:** One spring per commit keeps ordered placements consistent and honors Reduce Motion in one place. A spring per instruction would stagger rows that were inserted together and would repeat the Reduce Motion check for each one.
- **Q:** Why mark a group rather than animate every commit? **A:** Most of the screen does not move as a unit. Only the groups the program marked should move with a spring; the rest change at once.

## Referenced by

[[src/cbits/_MOC]] · [[iOS Host Adapter]] · [[Std Mobile View]] · [[Native iOS Capabilities Delivery]]
