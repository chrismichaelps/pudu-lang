---
type: module
path: "@root/lib/Std/Mobile/Feedback.pudu"
fidelity: Active
domain: "[[Pudu Native]]"
subsystem: "[[Standard Library]]"
grammar: "[[grammar/pudu]]"
tags: [module, stdlib, mobile, native, ui]
aliases: [Std Mobile Feedback]
---

# Std Mobile Feedback

## Purpose and interface

Pure description of the one-shot feedback a program asks the platform for: an alert, an action sheet, and a haptic. Each is a command. The module builds the commit that carries it, and the choice a person makes comes back as a CHOSE event that [[Std Mobile View]] decodes. The module imports [[Std Mobile Stream]] and encodes ALERT and HAPTIC through it.

Exports:
- `type Role = Plain | Cancel | Destructive`: how a choice reads. Codes 0, 1 and 2 in that order.
- `type Choice = { label: Str, role: Role }`: one choice of an alert or a context menu.
- `type Style = Centered | Sheet`: a centered alert, or an action sheet anchored to the bottom edge. Codes 0 and 1.
- `type Alert = { tag: UInt32, style: Style, title: Str, message: Str, choices: Array[Choice] }`: an alert the program asks the platform to show. The choice taken arrives as `Chose(tag, index)` with the index into `choices`.
- `type Haptic = Selection | Light | Medium | Heavy | Success | Warning | Failure`: a tactile response. Codes 1 to 7 in that order.
- `alert(alert: &Alert) -> Bytes`: a commit that shows the alert.
- `haptic(haptic: Haptic) -> Bytes`: a commit that plays the haptic.
- `choices(items: &Array[Choice]) -> Array[(UInt32, Str)]`: the choices as role codes and labels, the form ALERT and MENU carry.

## Invariants

- Role, style and haptic codes come from the constant tables `ROLES`, `STYLES` and `HAPTICS`. No code is chosen by an if-ladder or a match.
- The choices keep their order. The index in a CHOSE event indexes the `choices` the program supplied.
- A haptic code is never zero. Code 0 is never written.
- The platform shows one alert at a time. Later alerts queue behind it, in the order the program sent them.

## Negative Logic

- No view. An alert is not a node and is not part of `View.update`; it has no persistent state in the tree.
- No stored result. The module never records which choice was taken; the program receives it as an event.
- No outcome for a haptic. A haptic is played and reports nothing.
- No platform call. The presentation is made by [[iOS Host Feedback]].

## Dependencies and consumers

Depends on [[Std Mobile Stream]] for the ALERT and HAPTIC instructions. Consumers: [[Std Mobile View]], whose `Menu` wrapper takes `Choice` values and whose `Chose` event reports the choice taken; the host [[iOS Host Feedback]]; the example [[Native Showcase Example]]; and the fixture [[Uses Mobile Capabilities]].

## Resolved Grill Log

- **Q:** Why commands rather than views for alerts and haptics? **A:** They are one-shot effects with a reported outcome, not persistent state. A view would keep an alert in the tree after it was dismissed, and a haptic has no place in a tree at all. The host queues alerts so that one shows at a time.
- **Q:** Why a closed sum for roles and styles? **A:** The platform has a fixed set of each. A closed sum is exhaustive, so a new role is a compile-time change, not a string the host must guess at.

## Referenced by

[[src/Std/_MOC]] · [[Std Mobile View]] · [[Std Mobile Stream]] · [[iOS Host Feedback]] · [[Native iOS Capabilities Delivery]]
