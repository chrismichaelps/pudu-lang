---
type: module
path: "@root/test/native/DesktopWindow.m"
fidelity: Active
aliases: [Desktop Window Test]
tags: [module, test, desktop, macos]
---
# Desktop Window Test

Open a real window through the adapter's C entry points and drain its records. Require exactly one
`scale` record matching the window's backing scale after open. Require
`pudu_desktop_configure` to refuse each invalid argument (density out of range, negative or
inverted limits, half aspect, non-boolean full screen) with status -1 and leave the window as it
was; apply limits and a 16:9 aspect in points; clear the aspect again; and size the content of a
640x360 frame presented at density 2000 to 320x180 points while a density-1000 frame keeps its
pixel size. With `PUDU_LIVE_DESKTOP=1` it also requires a `focus` record, miniaturizes and restores the window and enters
and leaves full screen, requiring the matching records within a bounded pump, since those
transitions need an interactive window server.

## Referenced by

[[Desktop Presentation Gate]] · [[Pudu Desktop Adapter]] · [[Pudu Desktop Window]]
