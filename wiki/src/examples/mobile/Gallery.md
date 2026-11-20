---
type: module
path: "@root/examples/mobile/Gallery.pudu"
fidelity: Active
domain: "[[Pudu Native]]"
tags: [module, example, mobile, native, image]
aliases: [Gallery Example]
---

# Gallery Example

## Purpose and interface

A program that shows four images from three sources on the iOS simulator. It exercises an asset image, a served image, a missing image, and an image moved from a slow source to an asset as soon as the asset loads. Labels above the images report the counts and whether the move happened, so the simulator run reads the same answers the host reports.

The images, in order, with their tags:
- Tag 1: `pudu.png` from the assets, scaled Fit. Shared by every example in `examples/mobile/assets`.
- Tag 2: `/photo.png` from the fetch server, scaled Fill.
- Tag 3: `/missing.png` from the fetch server, which answers 404, scaled Fit.
- Tag 4: starts as `/slow.png`, a remote source delayed by 1.5 seconds, scaled Stretch. It becomes `pudu.png` from the assets when tag 1 reports loaded.

The labels are `Loaded: N`, `Failed: N` and `Moved: BOOL`. A loaded report counts once per source set. A failed report counts in `Failed`. The move happens on the first loaded report of tag 1, and the slow answer for tag 4 is dropped by the host because the view no longer shows that source.

The base address is read from `PUDU_FETCH_BASE`, defaulting to `http://127.0.0.1:8080`. The fetch server in `test/fetch-server.mjs` answers `/photo.png`, which is served at once, and `/slow.png`, which waits 1.5 seconds before it answers. Its `/missing.png` is a 404.

The example uses [[Std Mobile Control]] for the image values, [[Std Mobile View]] for the tree, [[Std Mobile Events]] for the report, and [[Std Mobile Host]] for the apply and wait calls.

## Simulator expectations

The iOS simulator run expects these labels: `Loaded: 3`, `Failed: 1`, `Moved: true`. The image lines are `PUDU_IMAGE` lines of the self-test in [[pudu-ios-image]]:

| Tag | Loaded | Size |
| --- | --- | --- |
| 1 | 1 | 48x48 |
| 2 | 1 | 96x96 |
| 3 | 0 | 0x0 |
| 4 | 1 | 48x48 |

The photo is requested once. The slow source for tag 4 is never shown.

## Invariants

- The moved image shows the bundled source once the bundled image has loaded, and never the slow source after that.
- Each label is computed from the model, which is updated only by image reports.
- The program makes no decision about image decoding; the host sizes and caches every image.

## Negative Logic

- No retry of the missing image. A failure is shown as a count.
- No timer in the program. The delay of the slow source is the server's.
- No write to the assets directory.

## Dependencies and consumers

Depends on [[Std Mobile Control]], [[Std Mobile View]], [[Std Mobile Events]], [[Std Mobile Host]] and [[Std Env]]. The host is [[iOS Host Adapter]] with [[pudu-ios-image]]. Its fixture-level counterpart is [[Uses Mobile Image]]. Assets are packaged by [[Backend Toolchain Assets]].

## Resolved Grill Log

- **Q:** Why move an image off a slow source rather than only show the slow one? **A:** It shows that a late answer for a replaced source is dropped and that a source change cancels the load in flight. Without a move there is nothing to check.
- **Q:** Why one bundled asset shared by every example? **A:** The examples in one directory share one asset set, so the packaging path is exercised once and every example reads the same file name.
- **Q:** Why a 404 rather than a closed connection for the missing image? **A:** A 404 is a normal server answer, so it tests the status check. A transport failure is the separate case of an unreachable address.

## Referenced by

[[src/examples/README]] · [[src/examples/README]] · [[Uses Mobile Image]] · [[pudu-ios-image]] · [[Native Images Delivery]] · [[NATIVE-MOBILE]]
