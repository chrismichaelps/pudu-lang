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

`synchronise` makes `pudu.lock` and `deps/` match a manifest's text: expand dependencies (path packages are read in place, git revisions are checked out, a repository's own path dependencies are refused), solve, fetch registry archives, check that no two packages (nor the project) own one module root and that no package ships `Std` or `Core`, build lock entries (git: source with requested revision and commit, tree digest; registry: archive digest), refuse any change under `--locked`, write the lock atomically, and materialise `deps/`. Dependencies are expanded, fetched, and copied side by side through `Package.Concurrent`, sharing one `GitSession`, and each step is reported to `optionProgress`. An installed package carries a marker with the locked checksum, its tree digest, and its fingerprint: an unchanged fingerprint is trusted, a changed one is settled by hashing, so an edited file is noticed and restored. Every package that must be copied is staged as `<destination>.partial` and verified (a git package's copy must have the locked digest) before anything changes; if any fails, the staged copies are removed and neither the lock nor `deps/` changes. Otherwise the lock is written, each staged copy replaces its destination by rename, and anything in `deps/` the lock does not name is removed. `openProject` finds the governing manifest from the working directory.

See [[architecture/PACKAGES]].

## Grill Log

- **Q:** How is a GitHub package locked? **A:** `github+<repository url>#<commit>` with the checkout's tree digest, checked on every copy like a git dependency. _Rationale:_ the tag may move; the commit and the files may not.

- **Q:** Write the lock before copying? **A:** After every package is staged and verified. _Rationale:_ a failed install must leave the project as it was. _Rejected:_ writing the lock first and repairing on the next run.

- **Q:** Execute anything a dependency contains? **A:** Never. _Rationale:_ install-time code is how worms spread through package ecosystems. _Rejected:_ hooks and build scripts.
- **Q:** Trust `deps/` as installed? **A:** No; compare against the recorded digest. _Rationale:_ an edited dependency changes the program without changing the lock. _Rejected:_ presence checks only.
- **Q:** Trust a cached checkout when copying? **A:** No; the copy's digest must equal the lock's. _Rationale:_ the cache is shared by every project and may be damaged. _Rejected:_ trusting the cache.

Resolved Grill Log: behaviour covered by `test/Pudu/PackageSpec.hs`.
