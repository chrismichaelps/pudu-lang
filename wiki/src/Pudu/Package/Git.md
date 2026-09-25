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

`newGitSession offline progress` opens the state one install shares: one lock per repository and the set already fetched. `checkoutGit session url revision` answers a locked commit whose checkout is cached without starting git; otherwise it keeps a bare clone per URL under `$PUDU_HOME/cache/git/` (default `~/.pudu`), fetches heads and tags unless offline, already fetched this run, or the pinned commit is already in the clone, resolves the revision to a commit, and checks each commit out once into `cache/checkouts/<url>/<commit>` through a staging directory renamed into place, taking its tree digest as it is written. Fetches and checkouts are reported as `Package.Progress` events. `git` runs with prompts disabled, so a repository needing credentials fails with its reason.

See [[architecture/PACKAGES]].

`bareRepository session url reuse` answers the cached bare clone, fetching once per session unless `reuse` (a locked version is known) or offline; `gitIn` runs git against a bare clone and `gitWith` runs git with prompts disabled and standard input.

## Grill Log

- **Q:** Lock a tag? **A:** No, the commit it named. _Rationale:_ tags move. _Rejected:_ tag pins.
- **Q:** Fetch a repository whose locked commit is cached? **A:** No. _Rationale:_ a lock and a warm cache must make no network request. _Rejected:_ fetching on every install.

Resolved Grill Log: behaviour covered by `test/Pudu/PackageSpec.hs`.
