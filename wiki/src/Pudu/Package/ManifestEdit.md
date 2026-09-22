---
type: module
path: "@root/packages/pudu/v0.1/src/Pudu/Package/ManifestEdit.hs"
fidelity: Active
domain: "[[Pudu Program]]"
subsystem: "[[Tooling]]"
grammar: "[[grammar/haskell]]"
tags: [module, packages, manifest]
aliases: [Package Manifest Edit]
---

# Package Manifest Edit

## Purpose and interface

Edits one line of `pudu.toml`: `setDependency` replaces the line naming a key (quoted or not) or appends to `[dependencies]` (adding the section when absent), `removeDependency` removes it, and `setPackageVersion` sets `[package] version`. Registry keys are quoted because `@` and `/` cannot appear in a bare key. Comments, blank lines, and key order are preserved.

See [[architecture/PACKAGES]].

## Grill Log

- **Q:** Reformat the manifest on write? **A:** No. _Rationale:_ it is written by people. _Rejected:_ rendering from a parsed value.

Resolved Grill Log: behaviour covered by `test/Pudu/PackageSpec.hs`.
