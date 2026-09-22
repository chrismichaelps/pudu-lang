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

`pudu install [spec…] [--locked] [--offline] [--quiet|--verbose]`, `uninstall`, `update [name…]`, `upgrade [name…]`, `deps`, `tree`, against GitHub through [[Package GitHubIndex]]; packages named on the install line are always fetched. `upgrade` raises each registry requirement to `^` of the newest release the solver may choose and names each package whose major version changed. `install` writes each spec into the manifest (a registry package with no version is written `*` and then pinned to `^` of what was chosen), synchronises, and writes the manifest only on success, so a failed install leaves it untouched. While working, `Cli.Progress` shows a live line; the report then says how many packages were resolved and from where (fetched, from cache), the `+`/`-`/`~` changes, how many were installed or restored and how many were already up to date, the files written, for each newly installed package a real module to import, and the total time. Commands that change dependencies run on up to eight cores.

See [[architecture/PACKAGES]].

## Grill Log

- **Q:** Separate package-manager executable? **A:** No. _Rationale:_ one tool. _Rejected:_ a second binary.

Resolved Grill Log: behaviour covered by `test/Pudu/PackageSpec.hs`.
