---
type: module
path: "@root/lib/Std/Mobile/Auth.pudu"
fidelity: Active
domain: "[[Pudu Native]]"
subsystem: "[[Standard Library]]"
grammar: "[[grammar/pudu]]"
tags: [module, stdlib, mobile, native, authentication]
aliases: [Std Mobile Auth]
---

# Std Mobile Auth

## Purpose and interface

Pure description of the device-owner confirmation request (#989). The module builds the AUTHENTICATE instruction through [[Std Mobile Request]] and performs no I/O. The answer arrives as an `Authenticated` event that [[Std Mobile View]] decodes, using the decoders of [[Std Mobile Events]].

Exports:
- `authenticate(tag: UInt32, reason: Str) -> Bytes`: asks the person to confirm they own the device. The reason text is shown by the platform prompt.

## Behavior

- Each request produces exactly one `Authenticated(tag, Bool)` answer under its tag.
- The answer is `true` only when the person confirmed. A failed attempt, a cancelled prompt, and a device with no biometrics and no passcode all answer `false`.
- The module does not report which factor was used. The platform does not offer a portable answer to that question.

## Invariants

- The request carries the tag as its first word and the reason as length-prefixed UTF-8 text.
- The module imports only [[Std Mobile Request]].

## Negative Logic

- No retry. A failed confirmation is answered as `false`; the program decides whether to ask again.
- No credential. The module never receives or stores a passcode or a biometric result.
- No silence. A request is always answered, so a program waiting on its tag is released.
- No platform call. The prompt is shown by [[pudu-ios-media]]'s sibling host code in [[PuduAuth]] and the iOS authentication handler of [[pudu-ios-services]].

## Dependencies and consumers

Depends on [[Std Mobile Request]] for the AUTHENTICATE instruction and on [[Std Mobile Events]] for AUTHENTICATED. Consumers: [[Std Mobile View]]; the Android host [[PuduAuth]]; the fixture [[Uses Mobile Services]]; and the example [[Toolbox Example]].

## Resolved Grill Log

- **Q:** Why confirm device ownership rather than biometrics alone? **A:** A person without enrolled biometrics can still confirm with the passcode. A biometric-only request would refuse them with no way through.
- **Q:** Why does the answer not say which factor was used? **A:** A program that needs that fact has no portable way to ask for it, since the platforms expose different factors. A single boolean is the only answer both platforms give exactly.
- **Q:** Why is there exactly one answer per request? **A:** A program waiting on a tag must always be released. A cancelled or unavailable prompt is an answer of `false`, not silence.
- **Q:** Why is a device with no lock set answered as `false`? **A:** No confirmation is possible, so reporting success would claim ownership the platform never checked. _Rejected:_ answering `true` when no lock exists, which would let a program skip the check on such devices.

## Referenced by

[[src/Std/_MOC]] · [[Std Mobile View]] · [[Std Mobile Request]] · [[Std Mobile Events]] · [[PuduAuth]] · [[Uses Mobile Services]] · [[Toolbox Example]] · [[NATIVE-MOBILE]]
