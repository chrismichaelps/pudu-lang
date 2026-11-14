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
