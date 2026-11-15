---
type: module
path: "@root/cbits/pudu_ios_material.h"
fidelity: Active
tags: [module, host, ios, native, objective-c]
aliases: [iOS Host Material]
---

# iOS Host Material

## Purpose and interface

Private material implementation of the iOS host, included once by [[iOS Host Adapter]]. The compiler stages it with the other private headers ([[Native Toolchain Host Sources]]). It owns the MATERIAL kind, the MATERIAL instruction, the realization of each material as a platform view, and the self-test that reports which realization a node received. The header is the first platform API adopted through both gates of [[Native Platform Adoption]].

The header handles one instruction of [[Std Mobile Stream]]: MATERIAL (26), and the kind MATERIAL (9).

## Behavior

- A material node is a visual-effect view whose content view holds a vertical stack. Children are placed in that stack, so INSERT, MOVE, APPEND and REMOVE work as they do for a column.
- Realization by material:

| Material | iOS 26 or later, built with SDK 26 or later | otherwise |
| --- | --- | --- |
| Thin | glass, clear style | system thin material blur |
| Regular | glass, regular style | system material blur |
| Thick | glass, regular style | system thick material blur |

- Build-time gate: the glass branch is compiled only when the SDK declares iOS 26 (`__IPHONE_26_0` is defined and the maximum allowed version is at least that). An SDK older than 26 compiles the blur branch only.
- Run-time gate: an availability check selects glass on iOS 26 or later. Older systems take the blur, even when the app was built with the newer SDK.
- A material code outside 1 to 3 is a stream defect. The host ends the process with a message naming the defect.
- Each material node records which realization it used, so the self-test can report it.
- Self-test `PUDU_UI_MATERIAL_TEST`: prints `PUDU_MATERIAL glass` or `PUDU_MATERIAL blur` for the first material node, then asks the program to stop.

## Invariants

- Every platform call of this header runs on the thread that runs the program.
- A material node always has a realization. The glass branch and the blur branch are the only two; no material is drawn as nothing.
- The realization of a node is fixed when the node is created by its MATERIAL instruction and does not change on later commits.

## Negative Logic

- No fallback to a plain background. A material the host cannot realize is a defect, never a silent no-op.
- No refusal on an older system. Glass and blur are the same capability at different fidelity.
- No material is drawn by the program. The program sends a code; the header chooses the view.
- No stream reading. This header never decodes an instruction and never looks up a node outside its own handler.

## Dependencies and consumers

Depends on UIKit and, when the SDK declares iOS 26, on the glass effect of UIKit. Included by [[iOS Host Adapter]]. Its instruction is encoded by [[Std Mobile Stream]] and its node is placed by [[Std Mobile View]] through the `Surfaced` wrapper. Staged by [[Backend Toolchain App]] and listed in [[Native Toolchain Host Sources]]. The self-test is run by [[iOS Simulator Run]] through [[Native Glass Example]].

## Resolved Grill Log

- **Q:** Why fall back to blur instead of refusing? **A:** Glass and blur are the same capability, a material behind content; an older system degrades appearance, not function. A material the host cannot realize at all is a defect, never a silent no-op.
- **Q:** Why both gates? **A:** The build-time gate keeps an older SDK compiling; the run-time gate keeps an app built with the new SDK working on older systems.

## Referenced by

[[src/cbits/_MOC]] · [[iOS Host Adapter]] · [[Native iOS Materials Delivery]] · [[Native Platform Adoption]]
