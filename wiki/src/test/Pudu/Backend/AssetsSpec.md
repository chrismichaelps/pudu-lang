---
type: module
path: "@root/test/Pudu/Backend/AssetsSpec.hs"
fidelity: Active
tags: [module, test, backend, toolchain, assets]
aliases: [Assets Spec, Test Backend Assets]
---

# Assets Spec

## Purpose and interface

Property tests of [[Backend Toolchain Assets]]: which files an application carries as assets, and the names and links refused before anything is packaged. The module exports `assetProperties`, a list of named properties that the test runner executes once each in a temporary directory.

## Properties

1. Listing and staging: files under `assets`, including a nested `icons` folder, are listed by relative name in name order (`b.png`, then `icons/a-1_x.png`), and the nested file is staged under the same relative name.
2. Refused names: `café.png`, `.hidden` and `with space.png` are each refused, and the reason names the file.
3. Refused link: a symbolic link inside `assets` that points at a file outside it is refused, and the reason says `symbolic link`.
4. Absent directory: a program without an `assets` directory carries no assets; `assetDirectory` returns nothing.

## Invariants

- Each property compares the exact listing, the exact refusal reason or the exact staged path, never only that a result is present.
- Temporary directories are created for each property and removed afterwards.

## Negative Logic

- No iOS or Android packaging is run here. The bundle and package contents are checked by the simulator and the build tests of [[Backend Toolchain App]] and [[Backend Toolchain Android]].
- No content of an asset is read or compared.

## Dependencies and consumers

Depends on [[Backend Toolchain Assets]] and the QuickCheck and temporary-directory packages. Run by the backend test group of [[Main]].

## Resolved Grill Log

- **Q:** Why check each refusal separately? **A:** Each refusal is a different rule. A test with one bad name would pass if a different rule caught it, so each name and the link are checked alone.
- **Q:** Why check the staged path as well as the listing? **A:** A listing can be right while staging writes the wrong name, which would load on one platform only.

## Referenced by

[[src/test/_MOC]] · [[Backend Toolchain Assets]] · [[Native Images Delivery]]
