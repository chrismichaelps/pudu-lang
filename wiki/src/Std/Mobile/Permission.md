---
type: module
path: "@root/lib/Std/Mobile/Permission.pudu"
fidelity: Active
domain: "[[Pudu Native]]"
subsystem: "[[Standard Library]]"
grammar: "[[grammar/pudu]]"
tags: [module, stdlib, mobile, native, permission]
aliases: [Std Mobile Permission]
---

# Std Mobile Permission

## Purpose and interface

Pure description of the protected capabilities a program may ask the person to allow: camera, microphone, photos, location, notifications, contacts, calendar, Bluetooth and motion. The module defines one closed model of a kind and its state, the same on every platform. It builds the commits that ask the platform for a state and the words that carry them. It performs no I/O. Answers arrive as `View.Permissioned(kind, state)`, decoded by [[Std Mobile Events]] from the report PERMISSIONED (28). Words are spelled by [[Std Mobile Stream]]. Each kind a program requests must be declared in its manifest, as [[Pudu Backend Permissions]] checks at build time.

Exports:
- `type Kind = Camera | Microphone | Photos | PhotosAdd | Location | LocationAlways | Notifications | Contacts | Calendar | Bluetooth | Motion`: codes 0 to 10 in that order, read by `kindCode`.
- `type State = NotAsked | Granted | Limited | Provisional | Denied | Blocked | Unavailable`: codes 0 to 6 in that order, read by `stateOf`.
- `type Table = { states: Map[Kind, State] }`: the latest state reported for each kind.
- `check(kinds: &Array[Kind]) -> Bytes`: a commit asking where the kinds stand, without prompting. Each answers `Permissioned(kind, state)`.
- `request(kind: Kind) -> Bytes`: a commit asking the person to allow the kind. Answers `Permissioned(kind, state)`.
- `settings() -> Bytes`: a commit opening the application's page in the platform's settings.
- `table() -> Table`: a table that knows nothing yet.
- `recorded(held: Table, kind: Kind, state: State) -> Table`: the table after a report.
- `status(held: &Table, kind: Kind) -> Option[State]`: the last reported state, or nothing.
- `allows(state: State) -> Bool`: true for Granted, Limited and Provisional.
- `key(kind: Kind) -> Str`: the manifest key that declares the kind: `camera`, `microphone`, `photos`, `photos-add`, `location`, `location-always`, `notifications`, `contacts`, `calendar`, `bluetooth`, `motion`.
- `kindCode(kind: Kind) -> UInt32`: the stream code of a kind, from the constant table `CODES`.
- `kindOf(code: UInt32) -> Option[Kind]`: the kind a code names, or nothing for a code no host writes.
- `stateOf(code: UInt32) -> Option[State]`: the state a code names, or nothing past 6.

## Behavior

- `check` sends PERMISSIONS (51) with the kind codes. The host reports each kind's current state and does not show a prompt.
- `request` sends PERMISSION (52) with one kind code. The host asks the person when the state is NotAsked, and reports the state at once when it is already decided.
- `settings` sends SETTINGS (53). It has no answer.
- `allows` is true only for states that let the program use the capability, in full or in part. Denied and Blocked are false. Unavailable is false, and so is NotAsked.
- `recorded` keeps one state per kind. A later report for a kind replaces the earlier one.

## State meaning

| State | Meaning | Who can change it |
|---|---|---|
| NotAsked | The person has not been asked. | The program may call `request`. |
| Granted | Allowed in full. | The person, in Settings. |
| Limited | Allowed in part: some photos or contacts, approximate location, or a write-only calendar. | The person, in Settings or the platform's picker. |
| Provisional | Notifications delivered quietly, without interrupting. | The person, in Settings. |
| Denied | Refused, but the platform allows another prompt. | The program may call `request` again. |
| Blocked | Refused, and the platform will not prompt again. | Only the person, in Settings. |
| Unavailable | Impossible on this device or under its restrictions. | Nobody in the application. |

## Invariants

- Every kind and state has one code, given by a constant table. No code is chosen by an if-ladder.
- The kind and state codes are the same on every host. A host that writes a code outside the table reports a defect.
- No request writes a node into the view tree. A permission is not a control; it has no place in the tree.

## Negative Logic

- No prompt from `check`. Reading a state never shows anything to the person.
- No stored answer. The module keeps the latest report in the table the program holds; it keeps nothing across launches.
- No platform call. The host in [[pudu-ios-permission]] and [[PuduPermission]] does the work.
- No import of the view. [[Std Mobile View]] imports this module for the `Permissioned` event; this module does not import the view, so the two do not form a cycle.

## Dependencies and consumers

Depends on [[Std Mobile Stream]] for the PERMISSIONS, PERMISSION and SETTINGS words. Consumers: [[Std Mobile Events]], which decodes PERMISSIONED with the kind and state tables; [[Std Mobile View]], which carries `Permissioned`; the fixture [[Uses Mobile Permission]]; the example [[Permissions Example]]; and the build check [[Pudu Backend Permissions]], which reads the kinds a program constructs.

## Resolved Grill Log

- **Q:** Why one closed state model across platforms rather than each platform's own names? **A:** A program branches on what it can do with the capability, not on how a platform spelled it. Blocked and Denied separate the two refusals that matter: Denied may be asked again, Blocked only in Settings. Limited covers the partial grants that look like a grant to a program but are not one: some photos or contacts, approximate location and a write-only calendar. Provisional is quiet notifications, which deliver without interrupting and so are usable. _Rejected:_ one boolean per platform, which would hide the difference between asking again and sending the person to Settings.
- **Q:** Why does the event carry typed values while this module does not import the view? **A:** The event is a view event, so [[Std Mobile View]] must name `Permission.Kind` and `Permission.State`. This module owns the types and the words, so it sits below the view. Importing the view back would form a cycle between the two modules. _Rejected:_ carrying the raw codes in the event and decoding them in the program, which would move the table out of the module that owns it.
- **Q:** Why are requests commits like feedback, not nodes? **A:** A permission request is a one-shot effect with one reported answer. A node would stay in the tree after the request finished, and a state has no place in the tree. [[Std Mobile Feedback]] makes the same choice for alerts.

## Referenced by

[[src/Std/_MOC]] · [[Std Mobile Stream]] · [[Std Mobile Events]] · [[Std Mobile View]] · [[Std Mobile System]] · [[Pudu Backend Permissions]] · [[Uses Mobile Permission]] · [[Permissions Example]] · [[NATIVE-MOBILE]]
