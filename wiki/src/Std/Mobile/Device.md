---
type: module
path: "@root/lib/Std/Mobile/Device.pudu"
fidelity: Active
domain: "[[Pudu Native]]"
subsystem: "[[Standard Library]]"
grammar: "[[grammar/pudu]]"
tags: [module, stdlib, mobile, native, device, network]
aliases: [Std Mobile Device]
---

# Std Mobile Device

## Purpose and interface

Pure description of the device facts and the reachability and keep-awake settings a program may request. Each request is a commit, like the system requests of [[Std Mobile System]]. The module builds the instructions through [[Std Mobile Stream]] and performs no I/O. The answers come back as events that [[Std Mobile View]] decodes: `Described` and `Networked`. The reports are decoded by [[Std Mobile Events]].

Exports:
- `type Platform = Ios | Android`: the platform that answered.
- `type Facts = { platform: Platform, version: Str, model: Str, locale: Str, zone: Str, textScale: Int }`: the device facts. `textScale` is the preferred text scale in percent, where 100 is the default.
- `type Link = Offline | Wifi | Cellular | Wired`: the kind of network path.
- `describe(tag: UInt32) -> Bytes`: a commit asking for the device facts. The answer is `Described(tag, facts)`.
- `watchNetwork(on: Bool) -> Bytes`: a commit that starts or stops reachability reports. The reports are `Networked(link)`.
- `keepAwake(on: Bool) -> Bytes`: a commit that keeps the screen on while the app is in front, or lets it sleep. It reports nothing.
- `facts(text: Str, scale: UInt32) -> Option[Facts]`: the facts carried by a `Described` event.
- `linkOf(code: UInt32) -> Option[Link]`: the link for a code, read from the const table `LINKS`.
- `linkCode(link: Link) -> UInt32`: the code of a link, read from the same table in the inverse direction.

The platform names are read from the const table `PLATFORMS` of type `Map[Str, Platform]`.

## Behavior

- `describe` names the tag its answer reports. The answer is produced once per request and is not repeated on its own.
- `facts` splits the text into exactly five lines: platform, system version, hardware model, locale and time zone. The detail of the event is the text scale. Text that is not exactly five lines, or that names an unknown platform, decodes to `Stopped` rather than to a partial record.
- `watchNetwork(true)` makes the host send `Networked` when watching starts and again on each change of link kind. A change within the same kind is not reported.
- `watchNetwork(false)` ends the reports. No later `Networked` event follows it.
- `keepAwake` is a standing setting. It holds until a later commit sets it again. The platform clears it when the app leaves the foreground, and the program sets it again when it returns.
- Facts are asked again when the program returns to the foreground, because the locale, time zone and text scale can change while the app runs.

## Invariants

- Every `describe` request carries a tag, and its `Described` answer carries the same tag.
- Link codes and platform names come from constant tables. No code is chosen by an if-ladder.
- Words for the network and keep-awake instructions carry one flag word: 1 to turn the setting on, 0 to turn it off. No other word is written.
- The module imports only [[Std Mobile Stream]].

## Negative Logic

- No stored facts. The module never caches the device facts; each answer arrives as an event.
- No boolean connectivity. The link kind is reported, and "online" is the link being any value other than `Offline`. A program that defers large transfers to Wi-Fi reads the kind.
- No guarantee of server reachability. A link is a statement that a network path exists. A request can still fail, and the program handles the failed `Fetched` answer.
- No platform call. The effects are made by the host in [[pudu-ios-device]] and [[PuduDevice]].
- No timed lease for keep-awake. The module offers no expiry; the program turns the setting off when its reason ends.

## Dependencies and consumers

Depends on [[Std Mobile Stream]] for the DEVICE, NETWORK and AWAKE instructions, and on the event decoders of [[Std Mobile Events]] for DESCRIBED and NETWORKED. Consumers: [[Std Mobile View]], which carries the `Described(UInt32, Device.Facts)` and `Networked(Device.Link)` cases; the iOS host [[pudu-ios-device]]; the Android host [[PuduDevice]]; the example [[About Example]]; and the fixture [[Uses Mobile Device]].

## Resolved Grill Log

- **Q:** Why one request for the facts rather than constants read at launch? **A:** The language, time zone and text scale change while the app runs. The program asks again when it returns to the foreground, so its view of the device is current without a watcher for each value.
- **Q:** Why a text of lines plus a detail word rather than a new record encoding? **A:** The answer reuses the existing text and detail event channel. No field can contain a newline on either platform, so five lines split without ambiguity. _Rejected:_ a binary record, which would need a second decoder on each host.
- **Q:** Why link kinds rather than a boolean? **A:** A program that defers large downloads to Wi-Fi needs the kind. "Online" is only the link being something other than `Offline`, so the kind subsumes the boolean.
- **Q:** Why report only on a change of kind? **A:** A change of path within the same interface kind would wake the program with nothing new to act on.
- **Q:** Why is keep-awake a standing setting rather than a timed lease? **A:** The platform already clears the setting when the app leaves the foreground. A timer would add a second owner for the same state, and the program knows when its reason has ended.

## Referenced by

[[src/Std/_MOC]] · [[Std Mobile View]] · [[Std Mobile Stream]] · [[Std Mobile Events]] · [[Std Mobile System]] · [[pudu-ios-device]] · [[PuduDevice]] · [[NATIVE-MOBILE]]
