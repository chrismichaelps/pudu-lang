---
type: module
path: "@root/test-fixtures/stdlib/UsesMobileDevice.pudu"
fidelity: Active
tags: [module, fixture, stdlib, mobile, native, device]
aliases: [Uses Mobile Device]
---

# Uses Mobile Device

## Purpose and interface

Stdlib fixture for device facts, reachability and keep-awake: the words of its requests in [[Std Mobile Device]] and [[Std Mobile Stream]], and the answers decoded by [[Std Mobile Events]]. Its entry `main` builds the instruction words for DEVICE, NETWORK and AWAKE, decodes the DESCRIBED event and the NETWORKED event in their valid and invalid forms, round-trips the link codes, and answers the number of checks that held. The data spec `test/Pudu/Compiler/Program/Eval/DataSpec.hs` asserts that count, which is `10`.

Checks, one per `if` of `main`:
1. DEVICE with tag 7 is 9 bytes; its words are 58 and 7.
2. NETWORK with `on` true is 5 bytes; its words are 59 and 1. NETWORK with `on` false is 5 bytes and its flag word is 0.
3. AWAKE with `on` false is 5 bytes; its words are 60 and 0.
4. DESCRIBED with tag 7, detail 120 and a five-line text decodes to `Described(7, Facts{Ios, ..., textScale: 120})`.
5. DESCRIBED with a four-line text decodes to `Stopped`.
6. DESCRIBED with an unknown platform name decodes to `Stopped`.
7. NETWORKED with detail 2 decodes to `Networked(Cellular)`.
8. NETWORKED with detail 4 decodes to `Stopped`.
9. `linkCode` of each link, read back through `linkOf`, returns the same link.
10. `linkOf` of a code above 3 is `None`.

## Invariants

- Each check compares an exact word, byte sequence or decoded value, so a wrong code, flag, tag or link fails the check.
- The fixture makes no foreign call and starts no host. It runs interpreted and as native C11 code, and both must agree.

## Negative Logic

- No reachability or keep-awake effect is checked here. Whether a link is reported and whether the screen stays awake are checked by the iOS simulator suite and the device run of [[About Example]].
- No refusal of an unknown flag word is checked here. The host refuses any word other than 0 and 1 as a stream defect, as [[pudu-ios-device]] and [[PuduDevice]] describe.

## Dependencies and consumers

Depends on [[Std Mobile Device]], [[Std Mobile Stream]] and [[Std Mobile Events]], and on the byte reader of `Std.ByteOrder`. Its checks mirror the contract that [[pudu-ios-device]] and [[PuduDevice]] rely on.

## Resolved Grill Log

- **Q:** Why are the platform names and link codes checked as a round trip? **A:** The tables are the only place a code is written and read. A round trip catches a table entry that maps to a neighbouring value, which a single decode would not.
- **Q:** Why is a four-line text a separate check from an unknown platform? **A:** The two are different defects. A short text means the host dropped a line; an unknown platform means the host named a platform the program does not know. Each must decode to `Stopped` for its own reason.
- **Q:** Why is an unknown link code left to `Stopped`? **A:** The hosts write only codes 0 to 3. A larger code is a host defect, and the decoder reads it as one rather than inventing a link kind.

## Referenced by

[[src/_MOC]] · [[Std Mobile Device]] · [[Std Mobile Stream]] · [[Std Mobile Events]] · [[About Example]] · [[NATIVE-MOBILE]]
