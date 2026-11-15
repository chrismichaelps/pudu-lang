---
type: module
path: "@root/lib/Std/Mobile/Access.pudu"
fidelity: Active
domain: "[[Pudu Native]]"
subsystem: "[[Standard Library]]"
grammar: "[[grammar/pudu]]"
tags: [module, stdlib, mobile, native, ui]
aliases: [Std Mobile Access]
---

# Std Mobile Access

## Purpose and interface

Pure description of what assistive technology reads about a control beyond its name: its traits, a hint that says what acting on it does, and its current value. [[Std Mobile View]] carries an `Access` in its `Accessible` wrapper, and the host applies it through the TRAITS, ACCESS_HINT and ACCESS_VALUE instructions of [[Std Mobile Stream]]. The module owns the bit of each trait in the TRAITS mask.

Exports:
- `type Trait`: every trait the platform defines, nineteen in all, listed below in bit order.
- `type Access = { traits: Array[Trait], hint: Str, value: Str }`: the traits, hint and value of one control.
- `mask(traits: &Array[Trait]) -> UInt32`: the TRAITS mask of a set of traits, the bitwise OR of their bits. An empty set is zero.

The nineteen traits in bit order:

| Bit | Trait | Mask |
| --- | --- | --- |
| 0 | Button | 1 |
| 1 | Link | 2 |
| 2 | Header | 4 |
| 3 | SearchField | 8 |
| 4 | Image | 16 |
| 5 | Selected | 32 |
| 6 | PlaysSound | 64 |
| 7 | KeyboardKey | 128 |
| 8 | StaticText | 256 |
| 9 | SummaryElement | 512 |
| 10 | NotEnabled | 1024 |
| 11 | UpdatesFrequently | 2048 |
| 12 | StartsMediaSession | 4096 |
| 13 | Adjustable | 8192 |
| 14 | AllowsDirectInteraction | 16384 |
| 15 | CausesPageTurn | 32768 |
| 16 | TabBar | 65536 |
| 17 | ToggleButton | 131072 (iOS 17 or later) |
| 18 | SupportsZoom | 262144 (iOS 17 or later) |

`ToggleButton` and `SupportsZoom` are announced on iOS 17 or later and ignored on earlier systems.

## Invariants

- Trait bits are fixed by the constant table `TRAITS` and never reordered. The mask is part of the wire, so a reordering would make the host apply a different trait.
- A trait outside the table contributes no bit.
- A mask of zero clears every trait the host applied.

## Negative Logic

- No name. A control's name is its label or button text, set by the view, not by this module.
- No announcement. Live announcements and custom actions are not part of this module.
- No trait that the platform does not define. The nineteen are the whole set this module offers.
- No platform call. The traits are applied by [[iOS Host Access]].

## Dependencies and consumers

Depends on no other Std Mobile module. Consumers: [[Std Mobile View]], whose `Accessible` wrapper carries an `Access`; [[Std Mobile Stream]], which receives the mask, the hint and the value; the host [[iOS Host Access]]; the example [[Native Showcase Example]]; and the fixture [[Uses Mobile Capabilities]].

## Resolved Grill Log

- **Q:** Why a trait set rather than one role? **A:** Platforms combine traits, so a control can be both a header and a button. A single role would lose one of them. _Rejected:_ one role sum.
- **Q:** Why is the bit order fixed in the module? **A:** The mask is part of the wire, so the order is the contract between the program and the host. A reordering would change which trait each bit names, and the change would pass every check that compares a whole mask.

## Referenced by

[[src/Std/_MOC]] · [[Std Mobile View]] · [[Std Mobile Stream]] · [[iOS Host Access]] · [[Native iOS Capabilities Delivery]]
