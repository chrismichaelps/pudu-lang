---
type: module
path: "@root/examples/mobile/Glass.pudu"
fidelity: Active
domain: "[[Pudu Native]]"
tags: [module, example, mobile, native]
aliases: [Native Glass Example]
---

# Native Glass Example

## Purpose and interface

A program that shows a material surface on the iOS simulator. It mounts a column holding a regular material surface, and inside the surface a label `Glass` and a Done button (tag 1). A tap on Done ends the program. The example exists to exercise the material realization of [[iOS Host Material]] on two runtimes.

The simulator suite runs it in two places, as described in [[iOS Simulator Run]]:
- On the newest installed runtime, which is iOS 26 or later. The run expects `PUDU_MATERIAL glass`.
- On the oldest available iOS runtime older than 26 (iOS 18.3 on the development Mac). The run expects `PUDU_MATERIAL blur`. If no runtime older than 26 is installed, the fallback run is skipped and the suite says so.

Both runs set `PUDU_UI_MATERIAL_TEST`. Each expects the label `Glass` in screen order and exit status 0.

## Invariants

- The surface is always mounted with the regular material, code 2. The example never changes its material, so one MATERIAL instruction is written.
- The realization line names the realization the host chose, not the one the program asked for.

## Negative Logic

- No material other than Regular is shown.
- No event besides the Done tap is handled.
- The example's text exists only to be read back by the self-test.

## Dependencies and consumers

Depends on [[Std Mobile View]] for `Surfaced`, `Column` and `Button`, and on [[Std Mobile Theme]] for `Regular`. Hosted by [[iOS Host Adapter]] with the material header [[iOS Host Material]]. Run by [[iOS Simulator Run]] on the newest and the oldest pre-26 runtime.

## Resolved Grill Log

- **Q:** Why run the example on two runtimes? **A:** Only the pair shows both realizations. A run on one runtime proves one branch; the glass branch and the blur branch are each reached only on their own runtime.
- **Q:** Why skip the fallback run when no pre-26 runtime exists? **A:** The suite cannot create a runtime. It reports the skip, so a missing runtime is visible rather than a pass.

## Referenced by

[[src/examples/README]] · [[iOS Simulator Run]] · [[Uses Mobile Material]] · [[Native iOS Materials Delivery]]
