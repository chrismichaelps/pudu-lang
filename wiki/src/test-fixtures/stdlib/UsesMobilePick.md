---
type: module
path: "@root/test-fixtures/stdlib/UsesMobilePick.pudu"
fidelity: Active
tags: [module, fixture, stdlib, mobile, native, pick]
aliases: [Uses Mobile Pick]
---

# Uses Mobile Pick

## Purpose and interface

Stdlib fixture for the pickers, recording, badge, secure screen and toast requests (#991): the words of [[Std Mobile Request]] for PICK_CONTACT, PICK_DOCUMENT, TAKE_PHOTO, RECORD, BADGE, SECURE and TOAST, the decoders of [[Std Mobile Pick]] and [[Std Mobile Events]] for CONTACT_PICKED and FILED. Its entry `main` builds the words, decodes each answer and answers the number of checks that held. The data spec `test/Pudu/Compiler/Program/Eval/DataSpec.hs` asserts that count, which is `8`.

Checks, one per `if` of `main`:

1. PICK_CONTACT with a tag writes its code 79 followed by the tag.
2. PICK_DOCUMENT with two MIME types writes code 80, the tag and the comma-joined types; an empty list writes an empty type field.
3. TAKE_PHOTO with a tag writes code 81 followed by the tag.
4. RECORD with on writes code 82, the tag and 1; with off, 0.
5. BADGE with a count above 0 writes its count, and a negative count writes 0.
6. SECURE with on writes code 84 followed by 1.
7. TOAST with text writes code 85 followed by the length-prefixed text.
8. CONTACT_PICKED with three lines decodes to a `Contact` with its name, phones and emails; a cancelled answer decodes to `None`; a malformed text with the wrong line count decodes to `None`. FILED decodes to its tag and path, or to a cancellation.

## Invariants

- Each check compares an exact word sequence or decoded value, so a wrong code, field order or decoded case fails the check.
- The fixture makes no foreign call and starts no host. It runs interpreted and as native code, and both must agree.

## Negative Logic

- No platform effect is checked here. Picker presentation, recording, badge drawing and toasts are checked by the iOS simulator suite and by [[Picker Example]].
- No check of the copy into the temporary directory. The host performs the copy.

## Dependencies and consumers

Depends on [[Std Mobile Request]], [[Std Mobile Pick]], [[Std Mobile System]], [[Std Mobile Events]] and the byte reader of `Std.ByteOrder`. Its checks mirror the contract that [[pudu-ios-pick]] and [[PuduPick]] rely on.

## Resolved Grill Log

- **Q:** Why is a cancelled contact checked as `None` and not as an empty contact? **A:** An empty contact is a valid value a program might display. A cancellation has no contact, so the decoder must not invent one.
- **Q:** Why is a negative badge count checked as 0? **A:** The host clears the badge for 0, so a negative count is written as 0 and clears it, rather than sending a value the host would have to reject.
- **Q:** Why are the words checked and not a round trip? **A:** A round trip passes if a field is written and read in the same wrong order. The exact words fix the order the host expects.

## Referenced by

[[src/_MOC]] · [[Std Mobile Request]] · [[Std Mobile Pick]] · [[Std Mobile Events]] · [[Picker Example]] · [[pudu-ios-pick]] · [[PuduPick]] · [[NATIVE-MOBILE]]
