---
type: module
path: "@root/lib/Std/Desktop/Bundle/Linux.pudu"
fidelity: Active
domain: "[[Pudu Program]]"
subsystem: "[[Standard Library]]"
grammar: "[[grammar/pudu]]"
tags: [module, stdlib, desktop, packaging, linux]
aliases: [Std Desktop Bundle Linux]
---

# Std Desktop Bundle Linux

## Purpose and interface

The installed layout every Linux package shares, and the `.deb` and AppImage writers. `layout` lists
the files; `desktopEntry` writes the launcher entry; `debArch` maps processors to Debian names
through a const table; `control` writes the Debian control file; `deb` writes the package natively;
`appImage` writes an AppDir and runs `appimagetool`.

## Semantics

- Layout: the executable at `/usr/lib/<pkg>/<pkg>` (mode `0755`) with `app.tar.gz` beside it (which
  is where [[Std Desktop App]] `locateAssets` looks), a `/usr/bin/<pkg>` link to it, the desktop entry
  at `/usr/share/applications/<pkg>.desktop`, and a PNG icon under `hicolor/256x256/apps` when one is
  configured.
- The Debian package is an `ar` archive of `debian-binary` (`2.0`), `control.tar.gz` and
  `data.tar.gz`, in that order. It depends on the WebKitGTK and GTK runtime libraries plus any
  configured dependencies, and states its installed size in KiB.
- The AppDir holds `AppRun`, the desktop entry and icon at its root, and the same `usr` tree; without
  a configured icon a one-pixel PNG is written, because the image tool requires one.
- With `gpgKey`, each package receives a detached ASCII-armored signature beside it.

## Grill Log

- **Q:** Why write the `.deb` natively but call a tool for AppImage? **A:** A Debian package is two
  tar archives in an `ar` archive, all of which Std already writes; an AppImage is a squashfs image
  appended to a runtime executable, and both are platform artifacts the tool exists to produce.

## Dependencies and consumers

Uses [[Std Desktop Bundle Config]], [[Std Desktop Bundle Binary]], [[Std Archive Tar]] and
[[Std Compress Gzip]]. Consumed by [[Std Desktop Bundle]] and [[Std Desktop Bundle Rpm]].

## Referenced by

[[src/Std/_MOC]]
