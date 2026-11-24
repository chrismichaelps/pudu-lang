---
type: module
path: "@root/test-fixtures/stdlib/UsesMobileCompose.pudu"
fidelity: Active
tags: [module, fixture, stdlib, mobile, native, compose]
aliases: [Uses Mobile Compose]
---

# Uses Mobile Compose

## Purpose and interface

Stdlib fixture for the system sheets (#994): the words of [[Std Mobile Request]] for SHARE_FILE, REVIEW, ADD_EVENT, COMPOSE_MAIL and COMPOSE_MESSAGE, and the COMPLETED decoder of [[Std Mobile Events]]. Its entry `main` builds the words, decodes each answer and answers the number of checks that held. The data spec `test/Pudu/Compiler/Program/Eval/DataSpec.hs` asserts that count, which is `7`.

Checks, one per `if` of `main`:

1. SHARE_FILE with a tag and a path writes code 86, the tag and the length-prefixed path.
2. REVIEW writes code 87 alone.
3. ADD_EVENT writes code 88, the tag, the start as two words (high, low), the end as two words, then the title and location.
4. COMPOSE_MAIL writes code 89, the tag, the comma-joined recipients, the subject and the body.
5. COMPOSE_MESSAGE writes code 90, the tag, the comma-joined recipients and the body.
6. COMPLETED with detail 1 decodes to `Completed` with true; with detail 0, to false.
7. COMPLETED with detail 2, which the host never sends, decodes to a stopped stream.

## Invariants

- Each check compares an exact word sequence or decoded value, so a wrong code, field order or decoded case fails the check.
- The fixture makes no foreign call and starts no host. It runs interpreted and as native code, and both must agree.

## Negative Logic

- No platform effect is checked here. Sheet presentation is checked by the iOS simulator suite and by [[Outbox Example]].
- No check of the file copy or the provider. [[PuduFiles]] is not exercised by the fixture.

## Dependencies and consumers

Depends on [[Std Mobile Request]], [[Std Mobile Compose]], [[Std Mobile System]], [[Std Mobile Events]] and the byte reader of `Std.ByteOrder`. Its checks mirror the contract that [[pudu-ios-compose]] and [[PuduCompose]] rely on.

## Resolved Grill Log

- **Q:** Why are the times checked as words and not as a round trip? **A:** A round trip passes when a field is written and read in the same wrong order. The exact words fix the high-first order the host expects.
- **Q:** Why is a malformed COMPLETED detail checked as a stopped stream? **A:** A detail the host never sends means the stream is wrong. The decoder must stop rather than read the value as a cancellation.
- **Q:** Why check REVIEW, which writes a single word? **A:** The check fixes code 87 with no tag, the word the host dispatches on, so a changed code fails here.

## Referenced by

[[src/_MOC]] · [[Std Mobile Request]] · [[Std Mobile Compose]] · [[Std Mobile Events]] · [[Outbox Example]] · [[pudu-ios-compose]] · [[PuduCompose]] · [[NATIVE-MOBILE]]
