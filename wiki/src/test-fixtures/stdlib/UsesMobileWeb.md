---
type: module
path: "@root/test-fixtures/stdlib/UsesMobileWeb.pudu"
fidelity: Active
tags: [module, fixture, stdlib, mobile, native, web]
aliases: [Uses Mobile Web]
---

# Uses Mobile Web

## Purpose and interface

Stdlib fixture for the web, video, audio, keyboard and back requests (#990): the words of [[Std Mobile Control]] for the Web and Video variants, the writers of [[Std Mobile Stream]] and [[Std Mobile Request]] for AUDIO, KEYBOARD and BACK, and the answers decoded by [[Std Mobile Events]] for LOADED, ENDED and BACKED. Its entry `main` builds the words, decodes each answer and answers the number of checks that held. The data spec `test/Pudu/Compiler/Program/Eval/DataSpec.hs` asserts that count, which is `10`.

Checks, one per `if` of `main`:

1. A web control created and loaded writes CREATE with kind 23, then LOAD 74 with its URL.
2. A video control created writes CREATE with kind 24, then MEDIA 75 with its playing and looping flags and source.
3. A web control unchanged from its prior state writes nothing.
4. A web control whose URL changes writes LOAD 74 with the new URL.
5. A web control whose tag changes answers `None`, so the caller replaces the node.
6. AUDIO with tag, playing, looping and source is its code followed by those fields in order.
7. KEYBOARD is its code alone.
8. BACK with 1 is its code followed by 1, and BACK with 0 is its code followed by 0.
9. LOADED with detail 1 decodes to `Loaded(tag, true)`, and LOADED with detail 0 decodes to `Loaded(tag, false)`.
10. ENDED with a tag decodes to `Ended(tag)`, BACKED decodes to `Backed`, and a malformed LOADED shape decodes to `Stopped`.

## Invariants

- Each check compares an exact word sequence or decoded value, so a wrong code, field order or decoded case fails the check.
- The fixture makes no foreign call and starts no host. It runs interpreted and as native code, and both must agree.

## Negative Logic

- No platform effect is checked here. Page loading, video playback, sound output and the back gesture are checked by the iOS simulator suite and by [[Viewer Example]].
- No check of the URL scheme rule. The host reads a scheme as remote, and any other text as a bundled asset.

## Dependencies and consumers

Depends on [[Std Mobile Control]], [[Std Mobile Stream]], [[Std Mobile Request]], [[Std Mobile Events]] and the byte reader of `Std.ByteOrder`. Its checks mirror the contract that [[pudu-ios-web]] and [[PuduWeb]] rely on.

## Resolved Grill Log

- **Q:** Why is a control's change checked by its words and not by a round trip? **A:** A round trip passes if a field is written and read in the same wrong order. The exact words fix the order the host expects.
- **Q:** Why does a tag change answer `None` rather than write a partial update? **A:** A tag names the node. A different tag is a different node, so the caller replaces it, and no instruction can express that change on the existing node.
- **Q:** Why is the malformed LOADED checked inside the event check? **A:** A malformed answer is a host defect. It must decode to `Stopped` for its own reason, rather than to a partial `Loaded`.

## Referenced by

[[src/_MOC]] · [[Std Mobile Control]] · [[Std Mobile Stream]] · [[Std Mobile Request]] · [[Std Mobile Events]] · [[Viewer Example]] · [[pudu-ios-web]] · [[PuduWeb]] · [[NATIVE-MOBILE]]
