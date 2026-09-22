---
type: module
path: "@root/packages/pudu/v0.1/src/Pudu/Package/Git.hs"
fidelity: Active
domain: "[[Pudu Program]]"
subsystem: "[[Tooling]]"
grammar: "[[grammar/haskell]]"
tags: [module, packages, git]
aliases: [Package Git]
---

# Package Git

## Purpose and interface

`checkoutGit offline url revision` keeps a bare clone per URL under `$PUDU_HOME/cache/git/` (default `~/.pudu`), fetches heads and tags unless offline, resolves the revision to a commit, and checks each commit out once into `cache/checkouts/<url>/<commit>` through a staging directory renamed into place. `git` runs with prompts disabled, so a repository needing credentials fails with its reason.

See [[architecture/PACKAGES]].

## Grill Log

- **Q:** Lock a tag? **A:** No, the commit it named. _Rationale:_ tags move. _Rejected:_ tag pins.

Resolved Grill Log: behaviour covered by `test/Pudu/PackageSpec.hs`.
