---
type: module
path: "@root/test-fixtures/stdlib/UsesMobileServices.pudu"
fidelity: Active
tags: [module, fixture, stdlib, mobile, native, services]
aliases: [Uses Mobile Services]
---

# Uses Mobile Services

## Purpose and interface

Stdlib fixture for the device services batch (#989): the words of the instructions of [[Std Mobile Notify]], [[Std Mobile Auth]], [[Std Mobile Media]] and [[Std Mobile Device]], and the answers decoded by [[Std Mobile Events]]. Its entry `main` builds the instruction words, decodes each event, and answers the number of checks that held. The data spec `test/Pudu/Compiler/Program/Eval/DataSpec.hs` asserts that count, which is `18`.

Checks, one per `if` of `main`:

Instruction words (11):
1. NOTIFY with id, delay and text is its instruction code followed by the id, delay and text fields.
2. UNNOTIFY with an id is its code followed by the id.
3. AUTHENTICATE with tag and reason is its code followed by the tag and reason.
4. BROWSE with tag and URL is its code followed by the tag and URL.
5. SPEAK with tag, rate, language and text is its code followed by those fields in order.
6. HUSH is its code alone.
7. BATTERY with tag is its code followed by the tag.
8. BRIGHTNESS with percent is its code followed by the percent.
9. ORIENTATION with a lock code is its code followed by the code.
10. SENSE with on and interval is its code followed by the on word and the interval.
11. PICK_IMAGE with tag is its code followed by the tag.

Event decodes (7), each with its valid form:
12. NOTIFIED with a tag decodes to `Notified`.
13. AUTHENTICATED with detail 1 decodes to `Authenticated(tag, true)`.
14. BROWSED with a tag decodes to `Browsed`.
15. SPOKE with detail 1 decodes to `Spoke(tag, true)`.
16. POWERED with a charge and a level decodes to `Powered`; a malformed POWERED with a charge outside the table is refused and decodes to `Stopped`.
17. SENSED with three words decodes to `Sensed`; a malformed SENSED with two words is refused and decodes to `Stopped`.
18. IMAGE_PICKED with detail 1 and a path decodes to `ImagePicked(tag, Some(path))`.

The two refusals of POWERED and SENSED are part of checks 16 and 17.

## Invariants

- Each check compares an exact word, byte sequence or decoded value, so a wrong code, field order or decoded case fails the check.
- The fixture makes no foreign call and starts no host. It runs interpreted and as native code, and both must agree.

## Negative Logic

- No platform effect is checked here. Notification delivery, authentication, speech and sensor values are checked by the iOS simulator suite and by [[Toolbox Example]].
- No range check of brightness or orientation is checked here. The host refuses a brightness above 100 and an orientation code above 2 as stream defects.

## Dependencies and consumers

Depends on [[Std Mobile Notify]], [[Std Mobile Auth]], [[Std Mobile Media]], [[Std Mobile Device]], [[Std Mobile Stream]] and [[Std Mobile Events]], and on the byte reader of `Std.ByteOrder`. Its checks mirror the contract that [[pudu-ios-services]], [[pudu-android-services]] and their Java classes rely on.

## Resolved Grill Log

- **Q:** Why is each instruction checked for its exact words rather than for a round trip? **A:** A round trip would pass if a field were written and read in the same wrong order. The exact words fix the order the host expects.
- **Q:** Why are the malformed POWERED and SENSED checked as refusals inside the event checks? **A:** Each is a host defect. Both must decode to `Stopped` for their own reason, rather than to a partial value.
- **Q:** Why is the count 18 and not one per instruction? **A:** The count is the number of distinct contracts: eleven instruction shapes and seven event decodes, with the refusals counted inside the decodes they guard.

## Referenced by

[[src/_MOC]] · [[Std Mobile Notify]] · [[Std Mobile Auth]] · [[Std Mobile Media]] · [[Std Mobile Device]] · [[Std Mobile Stream]] · [[Std Mobile Events]] · [[Toolbox Example]] · [[NATIVE-MOBILE]]
