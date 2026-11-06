---
type: module
path: "@root/lib/Std/Desktop/Bundle/Mac.pudu"
fidelity: Active
domain: "[[Pudu Program]]"
subsystem: "[[Standard Library]]"
grammar: "[[grammar/pudu]]"
tags: [module, stdlib, desktop, packaging, macos]
aliases: [Std Desktop Bundle Mac]
---

# Std Desktop Bundle Mac

## Purpose and interface

macOS packages. `infoPlist` writes the bundle's property list; `app` writes `<Name>.app` with the
executable in `Contents/MacOS`, the packed frontend and icon in `Contents/Resources`, then signs and
notarizes it when configured; `dmg` writes a compressed disk image holding the app and an
`Applications` link.

## Semantics

- The property list declares the name, display name, identifier, version (short and build),
  executable, package type `APPL`, icon, minimum system, high-resolution capability, category and
  copyright; every value is XML-escaped.
- An `.icns` icon is copied; a PNG is converted with `sips` and `iconutil` into the sizes the system
  asks for; no icon writes none.
- With `signingIdentity`, `codesign` signs with the hardened runtime and a secure timestamp, and the
  configured entitlements; without one, the app is signed ad hoc so it launches on Apple silicon.
- With `notarizeProfile`, the app is zipped with `ditto`, submitted with `notarytool` (waiting for
  the verdict), and stapled. A failed verdict is a `ToolFailed` carrying the tool's output.
- The disk image is built with `hdiutil` in UDZO format and signed with the same identity.

## Grill Log

- **Q:** Why sign ad hoc when no identity is configured? **A:** An unsigned executable does not
  start on Apple silicon at all; ad-hoc signing makes a local build runnable without pretending it is
  distributable.

## Dependencies and consumers

Uses [[Std Desktop Bundle Config]]. Consumed by [[Std Desktop Bundle]].

## Referenced by

[[src/Std/_MOC]]
