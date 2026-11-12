---
type: module
path: "@root/lib/Std/Desktop/Bundle.pudu"
fidelity: Active
domain: "[[Pudu Program]]"
subsystem: "[[Standard Library]]"
grammar: "[[grammar/pudu]]"
tags: [module, stdlib, desktop, packaging]
aliases: [Std Desktop Bundle]
---

# Std Desktop Bundle

## Purpose and interface

Writes every requested package format. `bundle(config, inputs, buildTime)` runs each target's
builder from a const factory table and answers what it produced; `updateArchive` writes the archive
an installed application is replaced with.

## Semantics

- Targets run in a fixed order (`app`, `dmg`, `deb`, `rpm`, `appimage`, `nsis`, `msi`), so a disk
  image always finds the app it holds; asking for `dmg` alone builds the app first.
- Each format writes under `<out>/<platform>`: `macos`, `linux` or `windows`.
- The first failing format stops the run with its `BundleError`; formats already written stay on
  disk and are listed by the caller from the error's context.
- The update archive for macOS holds the `.app` bundle's `Contents` tree; for other platforms the
  executable and `app.tar.gz`. Entries are written in a fixed order with fixed times, so equal inputs
  give equal archives and patches between versions stay small.

## Grill Log

- **Q:** Why a factory table rather than a match on the target name? **A:** Target names arrive as
  text from the configuration; the table is the one place a format is registered, and the
  configuration's list of valid targets is checked against the same names.

## Dependencies and consumers

Uses [[Std Desktop Bundle Config]], [[Std Desktop Bundle Mac]], [[Std Desktop Bundle Linux]],
[[Std Desktop Bundle Rpm]], [[Std Desktop Bundle Windows]] and [[Std Archive Tar]]. Consumed by
[[Std Desktop Cli]].

## Referenced by

[[src/Std/_MOC]] · [[architecture/DESKTOP-WEBVIEW]]
