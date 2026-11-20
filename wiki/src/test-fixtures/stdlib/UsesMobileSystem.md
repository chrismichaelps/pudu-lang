---
type: module
path: "@root/test-fixtures/stdlib/UsesMobileSystem.pudu"
fidelity: Active
tags: [module, fixture, stdlib, mobile, native, system]
aliases: [Uses Mobile System]
---

# Uses Mobile System

## Purpose and interface

Stdlib fixture for system requests: their words in [[Std Mobile System]] and [[Std Mobile Stream]], and their reports in [[Std Mobile Events]]. Its entry `main` builds the instruction words for OPEN, SHARE, COPY, PASTE and STATUS, decodes the OPENED and SHARED events and the PASTED text, and answers the number of checks that held. The data spec `test/Pudu/Compiler/Program/Eval/DataSpec.hs` asserts that count, which is `10`.

Checks, one per `if` of `main`:
1. OPEN with tag 3 and the URL `pudu-unhandled://nothing` writes the code 46, the tag and the length-prefixed URL, in the exact words.
2. SHARE with tag 4 and the text `from Pudu` writes the code 47, the tag and the length-prefixed text.
3. COPY of the text `from Pudu` writes the code 48 and the text.
4. PASTE with tag 5 writes the code 49 and the tag.
5. STATUS with style `LightText` and hidden false writes the code 50, the code 1 and the hidden flag 0.
6. STATUS with style `Automatic` and hidden true writes the code 50, the code 0 and the hidden flag 1.
7. OPENED with tag 3 and detail 1 decodes to `Opened(3, true)`.
8. OPENED with tag 3 and detail 0 decodes to `Opened(3, false)`.
9. SHARED with tag 4 and detail 1 decodes to `Shared(4, true)`, and SHARED with detail 0 decodes to `Shared(4, false)`.
10. PASTED with tag 5 and text `from Pudu` decodes to `Pasted(5, "from Pudu")`, and a PASTED with empty text decodes to `Pasted(5, "")`.

Any other OPENED or SHARED detail word decodes to `Stopped`; the fixture checks the 1 and 0 words only.

## Invariants

- Each check compares an exact word or byte sequence, so a wrong code, tag or length fails the check.
- The fixture makes no foreign call and starts no host. It runs interpreted and as native C11 code, and both must agree.

## Negative Logic

- No platform call. Whether the URL opens, what the share sheet does and what the clipboard holds are checked by the simulator and device runs of [[Services Example]], not here.
- No refusal is checked here. A style code past 2 and a hidden flag past 1 are refused by the host.

## Dependencies and consumers

Depends on [[Std Mobile System]], [[Std Mobile Stream]] and [[Std Mobile Events]]. Its checks mirror the contract that [[pudu-ios-system]] and [[PuduSystem]] rely on.

## Resolved Grill Log

- **Q:** Why check the bytes of each request rather than only that it runs? **A:** A wrong code or a swapped tag keeps the shape of the stream. Only the exact words catch it, as in [[Uses Mobile Image]].
- **Q:** Why is an empty paste a separate check? **A:** The host answers an empty clipboard with an empty text, not with a missing event. The decoder must read it as a value, not as a refusal.
- **Q:** Why are other detail words left to `Stopped`? **A:** The host writes only 0 and 1 for these answers. A third word would be a host defect, and the decoder reads it as one rather than inventing a meaning.

## Referenced by

[[src/_MOC]] · [[Std Mobile System]] · [[Std Mobile Stream]] · [[Std Mobile Events]] · [[Services Example]] · [[NATIVE-MOBILE]]
