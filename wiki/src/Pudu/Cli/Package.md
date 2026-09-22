---
type: module
path: "@root/packages/pudu/v0.1/src/Pudu/Cli/Package.hs"
fidelity: Active
domain: "[[Pudu Program]]"
subsystem: "[[Tooling]]"
grammar: "[[grammar/haskell]]"
tags: [module, cli, packages]
aliases: [Pudu CLI Package]
---

# Pudu CLI Package

## Purpose and interface

`pudu install [spec…] [--locked] [--offline]`, `uninstall`, `update [name…]`, `deps`, `tree`. `install` writes each spec into the manifest (a registry package with no version is written `*` and then pinned to `^` of what was chosen), synchronises, and writes the manifest only on success, so a failed install leaves it untouched. The report lists `+`, `-`, `~` changes, the files written, and for each newly installed package a real module to import.

See [[architecture/PACKAGES]].

## Grill Log

- **Q:** Separate package-manager executable? **A:** No. _Rationale:_ one tool. _Rejected:_ a second binary.

Resolved Grill Log: behaviour covered by `test/Pudu/PackageSpec.hs`.
