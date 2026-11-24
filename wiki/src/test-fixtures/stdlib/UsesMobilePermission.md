---
type: module
path: "@root/test-fixtures/stdlib/UsesMobilePermission.pudu"
fidelity: Active
tags: [module, fixture, stdlib, mobile, native, permission]
aliases: [Uses Mobile Permission]
---

# Uses Mobile Permission

## Purpose and interface

Stdlib fixture for permission requests: their words in [[Std Mobile Permission]] and [[Std Mobile Stream]], and their report in [[Std Mobile Events]]. Its entry `main` builds the PERMISSIONS, PERMISSION and SETTINGS words, round-trips every kind code, reads state codes, checks the manifest keys, the table and `allows`, and decodes PERMISSIONED. It answers the number of checks that held. The data spec `test/Pudu/Compiler/Program/Eval/DataSpec.hs` asserts that count, which is `10`.

Checks, one `held` increment each:
1. PERMISSIONS for Camera and Contacts writes 16 bytes: code 51, count 2, then kind codes 0 and 7.
2. PERMISSION for LocationAlways writes code 52 and kind code 5.
3. SETTINGS writes the single code 53 in 4 bytes.
4. Every kind code reads back as its kind, and code 11 reads as nothing.
5. State code 6 reads as Unavailable, and state code 7 reads as nothing.
6. The keys of PhotosAdd and LocationAlways are `photos-add` and `location-always`.
7. The table holds the latest report for Camera (Granted, after Denied), and reads nothing for Motion.
8. `allows` is true for Limited and Provisional, and false for Denied and Blocked.
9. PERMISSIONED with kind 0 and state 1 decodes to `Permissioned(Camera, Granted)`.
10. PERMISSIONED with an unknown kind 11, or a state 9, decodes to `Stopped`.

## Invariants

- Each check compares an exact word sequence, a code or a decoded value, so a wrong code or table entry fails the check.
- The fixture makes no platform call and starts no host. It runs interpreted and as native C11 code, and both must agree.

## Negative Logic

- No platform prompt. What the person allows, and how the platform reports it, is checked by the simulator run of [[Permissions Example]], not here.
- No refusal of an undeclared kind is checked here. That refusal is made at build time by [[Pudu Backend Permissions]].

## Dependencies and consumers

Depends on [[Std Mobile Permission]], [[Std Mobile Events]], [[Std Mobile View]] for the `Permissioned` value, and the byte order reader of [[Std ByteOrder]]. Its checks mirror the contract that [[pudu-ios-permission]] and [[PuduPermission]] rely on.

## Resolved Grill Log

- **Q:** Why check the bytes of PERMISSIONS and not only its decoded value? **A:** A wrong count or kind code keeps the shape of the stream, so only the exact words catch it, as in [[Uses Mobile System]].
- **Q:** Why does code 11 decode to nothing rather than to a default kind? **A:** No host writes a kind past 10. A default would turn a host defect into a kind the program never asked for.
- **Q:** Why are PERMISSIONED's unknown codes checked against both the kind and the state? **A:** The event carries two codes, and a bad value in either one must refuse the whole event. Checking only one would let a bad state read as a valid event with the wrong meaning.

## Referenced by

[[src/_MOC]] · [[Std Mobile Permission]] · [[Std Mobile Events]] · [[Std Mobile Stream]] · [[Permissions Example]] · [[Pudu Backend Permissions]] · [[NATIVE-MOBILE]]
