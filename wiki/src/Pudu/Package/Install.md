---
type: module
path: "@root/packages/pudu/v0.1/src/Pudu/Package/Install.hs"
fidelity: Active
domain: "[[Pudu Program]]"
subsystem: "[[Tooling]]"
grammar: "[[grammar/haskell]]"
tags: [module, packages, installation]
aliases: [Package Install]
---

# Package Install

## Purpose and interface

`synchronise` makes `pudu.lock` and `deps/` match a manifest's text: expand dependencies (path packages are read in place, git revisions are checked out, a repository's own path dependencies are refused), solve, fetch registry archives, check that no two packages (nor the project) own one module root and that no package ships `Std` or `Core`, build lock entries (git: source with requested revision and commit, tree digest; registry: archive digest), refuse any change under `--locked`, write the lock atomically, and materialise `deps/`. An installed package carries a marker with the locked checksum and its tree digest, so an edited file is noticed and restored; anything in `deps/` the lock does not name is removed. `openProject` finds the governing manifest from the working directory.

See [[architecture/PACKAGES]].

## Grill Log

- **Q:** Execute anything a dependency contains? **A:** Never. _Rationale:_ install-time code is how worms spread through package ecosystems. _Rejected:_ hooks and build scripts.
- **Q:** Trust `deps/` as installed? **A:** No; compare against the recorded digest. _Rationale:_ an edited dependency changes the program without changing the lock. _Rejected:_ presence checks only.

Resolved Grill Log: behaviour covered by `test/Pudu/PackageSpec.hs`.
