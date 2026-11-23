---
type: module
path: "@root/packages/pudu/v0.1/src/Pudu/Backend/Toolchain/HostSources.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
aliases: [Native Toolchain Host Sources]
---

# Native Toolchain Host Sources

Select the packaged host translation units and link flags from a marker in
the generated C. Write their exact contents into a temporary directory
owned by [[Backend Toolchain]], and return compiler arguments.

## Resolved Grill Log

Embed the existing AppKit sources and headers at compiler build time and
register each file as a compiler input. Materialize them only when a macOS
program selects the desktop marker. Put the staging directory on the include path. Keep headers beside their translation
units and use one compiler invocation to preserve cancellation and atomic
publication. A program on another platform selects no AppKit source.

## Referenced by

[[src/Pudu/Backend/_MOC]] · [[Native Desktop Adapter Delivery]]

## iOS host source (#916)

The module embeds the iOS host translation unit and its private layout header as
`iosHostSources :: [(FilePath, String)]` for [[Backend Toolchain App]]. They are data inputs
to the compiler and are compiled into the simulator app.

## Native audio (#857)

Resolved Grill Log: Select the AudioToolbox sources with an audio marker. A single staging directory serves all selected bundles.

## iOS layout source (#919)

Resolved Grill Log: embed the private layout header beside the host from the same source list. The staging step writes the original bytes for both before clang runs. See [[iOS Host Layout]].

## iOS theme source (#923)

The iOS host sources now stage the private theme header `pudu_ios_theme.h` with the host translation unit and the layout header. All three are written unchanged before clang runs. See [[iOS Host Theme]].

## iOS event and list sources (#925)

The iOS host sources also stage `pudu_ios_events.h`, `pudu_ios_controls.h` and `pudu_ios_list.h` with the host translation unit and the other private headers. All six are written unchanged before clang runs. See [[iOS Host Events]], [[iOS Host Controls]] and [[iOS Host List]].

## iOS material source (#928)

The iOS host sources also stage `pudu_ios_material.h` with the host translation unit and the other private headers. All seven are written unchanged before clang runs. See [[iOS Host Material]].

## Resolved Grill Log for the portable loader

Embed the loader header in generated C11 and stage the same header beside bundled SQLite.

## iOS capability sources (#930)

The iOS host sources also stage `pudu_ios_gesture.h`, `pudu_ios_feedback.h`, `pudu_ios_access.h`, `pudu_ios_scene.h`, `pudu_ios_motion.h`, `pudu_ios_navigation.h` ([[pudu_ios_navigation.h]]), `pudu_ios_refresh.h` ([[pudu_ios_refresh.h]]) and `pudu_ios_capability_test.h` with the host translation unit and the other private headers. All of them are written unchanged before clang runs. See [[iOS Host Gesture]], [[iOS Host Feedback]], [[iOS Host Access]], [[iOS Host Scene]], [[iOS Host Motion]], [[iOS Host Refresh]] and [[iOS Host Capability Test]].

## iOS network source

The iOS host sources also stage `pudu_ios_fetch.h` ([[pudu_ios_fetch.h]]) immediately after `pudu_ios_refresh.h` and before `pudu_ios_capability_test.h`. It holds the FETCH, CANCEL and WAKE handlers and the URL session. The list therefore has eighteen entries in all: the host translation unit and seventeen private headers, each written unchanged before clang runs. See [[iOS Host Fetch]].

## iOS node table source

The iOS host sources also stage `pudu_ios_nodes.h` ([[pudu_ios_nodes.h]]) between `pudu_ios_motion.h` and `pudu_ios_navigation.h`, with the host translation unit and the other private headers. It holds the instruction codes, the control kinds and the node table that the capability headers read, so it is staged before any header that includes it. The list therefore has seventeen entries in all: the host translation unit and sixteen private headers, each written unchanged before clang runs.

The reader header [[iOS Host Stream]], pudu_ios_stream.h, is staged with the same private headers.

## Device sources (#983)

The iOS host sources stage `pudu_ios_device.h` ([[pudu-ios-device]]) with the other private headers, and the host translation unit includes it once. The Android sources stage `PuduDevice.java` ([[PuduDevice]]) with the other platform classes.
