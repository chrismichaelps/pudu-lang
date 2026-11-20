---
type: module
path: "@root/test-fixtures/stdlib/UsesMobileImage.pudu"
fidelity: Active
tags: [module, fixture, stdlib, mobile, native, image]
aliases: [Uses Mobile Image]
---

# Uses Mobile Image

## Purpose and interface

Stdlib fixture for images: their stream in [[Std Mobile Control]] and [[Std Mobile Stream]], and their report in [[Std Mobile Events]]. Its entry `main` builds and changes an image through `built` and `changed`, decodes the IMAGED event, and answers the number of checks that held. The data spec `test/Pudu/Compiler/Program/Eval/DataSpec.hs` asserts that count, which is 10 (check 1 counts twice, as its header and its name bytes).

Checks, one per `if` of `main`:
1. An asset image with scaling Fit and tag 7 builds as CREATE 22, TAG 5, then SOURCE 45 with origin 0, scaling 1 and the name `a.png`, then ROOT. The stream is 57 bytes, its first six words are exact, and the name bytes are exact.
2. A remote image with scaling Fill carries SOURCE 45 with origin 1, scaling 0 and the URL, whose length is 11 bytes.
3. An update with the same source, scaling and tag writes nothing.
4. A new scaling alone writes one SOURCE with scaling 2 and origin 0, 25 bytes in all.
5. A new source (a remote URL for an asset) writes one SOURCE with origin 1 and scaling 1.
6. A new tag replaces the node: CREATE 22 with a new node id, then TAG.
7. IMAGED with detail 1 decodes to `Imaged(7, true)`.
8. IMAGED with detail 0 decodes to `Imaged(7, false)`.
9. IMAGED with detail 2 decodes to `Stopped`; no other detail word is an image report.

## Invariants

- Each check compares an exact word or byte sequence, never a length alone, except check 1 where the total length is part of the contract.
- The fixture makes no foreign call and starts no host. It runs interpreted and as native C11 code, and both must agree.

## Negative Logic

- No decode and no network. The decoded size and the loaded state are checked by the simulator run of [[Gallery Example]], not here.
- No refusal is checked here. A bad origin, an image node that is not an image, and a scaling past 2 are refused by the host.

## Dependencies and consumers

Depends on [[Std Mobile Control]], [[Std Mobile View]], [[Std Mobile Stream]] and [[Std Mobile Events]]. Its checks mirror the contract that [[pudu-ios-image]] and [[PuduImage]] rely on.

## Resolved Grill Log

- **Q:** Why check the bytes of a source change rather than the event alone? **A:** A wrong scaling code or origin keeps the length and shape of the stream. Only the exact words catch it.
- **Q:** Why is the same source a no-op? **A:** A redraw of an unchanged image must not restart its load. The host would otherwise cancel and decode again on every frame.
- **Q:** Why does a new tag replace the node? **A:** IMAGED reports the tag. A changed tag must not be attributed to the old node's load, so the node is rebuilt, as the value controls do.

## Referenced by

[[src/_MOC]] · [[Std Mobile Control]] · [[Std Mobile Stream]] · [[Std Mobile Events]] · [[Uses Mobile Controls]] · [[Native Images Delivery]]
