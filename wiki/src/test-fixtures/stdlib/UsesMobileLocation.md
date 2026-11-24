---
type: module
path: "@root/test-fixtures/stdlib/UsesMobileLocation.pudu"
fidelity: Active
tags: [module, fixture, stdlib, mobile, native, location]
aliases: [Uses Mobile Location]
---

# Uses Mobile Location

## Purpose and interface

Stdlib fixture for device location: the words of its requests in [[Std Mobile Location]] and [[Std Mobile Stream]], and the answers decoded by [[Std Mobile Events]]. Its entry `main` builds the instruction words for LOCATE and TRACK, decodes the LOCATED event in its valid and invalid forms, and answers the number of checks that held. The data spec `test/Pudu/Compiler/Program/Eval/DataSpec.hs` asserts that count, which is `9`.

Checks, one per `if` of `main`:
1. LOCATE with tag 5 and accuracy Approximate is 3 words: 61, 5 and 1.
2. TRACK with `on` true, accuracy Approximate and distance 50 is 4 words: 62, 1, 2 and 50.
3. TRACK with distance -3 writes 0 as its distance word.
4. LOCATED with detail 1 and words 184655000, -661057000, 5 and 12 decodes to `Located(5, Some(Position{...}))`.
5. LOCATED with detail 0 and no words decodes to `Located(5, None)`.
6. LOCATED with detail 1 and three words decodes to `Stopped`.
7. LOCATED with detail 2 decodes to `Stopped`.
8. `carriesWords` of the LOCATED code with its words shifted into place is true.
9. `accuracyCode(Coarse)` is 2.

## Invariants

- Each check compares an exact word, byte sequence or decoded value, so a wrong code, tag, distance or coordinate fails the check.
- The fixture makes no foreign call and starts no host. It runs interpreted and as native C11 code, and both must agree.

## Negative Logic

- No location effect is checked here. Whether a position is found and whether tracking reports are sent are checked by the iOS simulator suite and the [[Where Example]] run.
- No refusal of an unknown accuracy is checked here. The host refuses any accuracy code above 2 as a stream defect.

## Dependencies and consumers

Depends on [[Std Mobile Location]], [[Std Mobile Stream]] and [[Std Mobile Events]], and on the byte reader of `Std.ByteOrder`. Its checks mirror the contract that [[pudu-ios-location]] and [[PuduLocation]] rely on.

## Resolved Grill Log

- **Q:** Why does one check compare the whole position record rather than one field? **A:** A swapped latitude and longitude, or a dropped altitude, would pass a single-field check. The record comparison catches each word's position.
- **Q:** Why is a negative distance checked as a write of 0? **A:** The stream carries an unsigned distance. A negative value written as is would reach the host as a huge distance and silently stop reports.
- **Q:** Why is a three-word position a separate check from a two-word one? **A:** Each is a different host defect. Both must decode to `Stopped` for their own reason, rather than to a partial position.

## Referenced by

[[src/_MOC]] · [[Std Mobile Location]] · [[Std Mobile Stream]] · [[Std Mobile Events]] · [[Where Example]] · [[NATIVE-MOBILE]]
