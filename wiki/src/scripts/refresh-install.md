---
type: module
path: "@root/scripts/refresh-install.sh"
fidelity: Active
tags: [module, tooling, installation, shell]
aliases: [Refresh Pudu Installation]
---

# Refresh Pudu Installation

## Purpose and interface

Build the selected production compiler, install it to an explicit directory (defaulting to
`~/.local/bin`), enumerate every `pudu` executable reachable on `PATH`, and prove the executable the
shell actually resolves through version, current-language, REPL, and LSP checks.

Multiple reachable paths are safe only when the resolved binary and newly installed binary are
byte-identical. Divergent binaries remain a hard failure with path-order guidance. This admits
Cabal's normal `~/.cabal/bin` symlink and a `~/.local/bin` install when both point to the same store
artifact, without weakening stale-binary detection.

## Negative logic

- The script does not delete competing installations or edit shell configuration.
- Equal version strings are not sufficient; development builds share a version, so bytes are compared.
- The proof never substitutes an in-tree executable for the path-resolved installation.

## Grill Log

- **Q:** Fail whenever more than one path exists? **A:** No. _Rationale:_ Cabal may create two
  symlinks to one exact store artifact. _Accepted:_ fail only when their bytes differ.
- **Q:** Automatically remove the earlier binary? **A:** No. _Rationale:_ path ownership belongs to
  the user and removal may break other environments. _Accepted:_ name both paths and require an
  explicit path-order decision only for divergent contents.

## Referenced by

[[Pudu Cabal Project]] · [[Pudu Cabal Manifest]] · [[src/_MOC]]
