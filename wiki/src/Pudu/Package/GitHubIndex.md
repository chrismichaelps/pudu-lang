---
type: module
path: "@root/packages/pudu/v0.1/src/Pudu/Package/GitHubIndex.hs"
fidelity: Active
domain: "[[Pudu Program]]"
subsystem: "[[Tooling]]"
grammar: "[[grammar/haskell]]"
tags: [module, packages, github, resolution]
aliases: [Package GitHubIndex]
---

# Package GitHubIndex

## Purpose and interface

`githubRegistry` answers the solver's `Registry` from GitHub repositories through the git cache. `@owner/repo` is `repositoryUrl base package` (`githubBase`: `PUDU_GITHUB_URL` or `https://github.com`). Releases are the tags reading as versions, with peeled commits and times from one `git for-each-ref` and the `pudu.toml` at every tag from one `git cat-file --batch`; a tag is a release only when that manifest names the package and gives the tag's version. Online and unlocked, `git ls-remote --tags` bounds the list to live tags. A locked version (from `lockedCommit` of its `github+<url>#<commit>` source) keeps its commit and is answered from the cached clone without fetching. `registryFetch` checks the commit out through `Package.Git`. `minimumAgeFor` reads `PUDU_MIN_RELEASE_AGE` or `[install] min-release-age` (72 hours), compared with the tag's time.

See [[architecture/PACKAGES]].

## Grill Log

- **Q:** Ask the GitHub API for tags? **A:** git. _Rationale:_ no rate limit, the same credentials as `git clone`, and the objects are needed anyway. _Rejected:_ `GET /repos/…/tags` from the CLI.
- **Q:** Trust any version tag? **A:** Only one whose `pudu.toml` names the package and the tag's version. _Rationale:_ a stray tag or a fork's manifest must never be chosen.
- **Q:** Prune deleted tags from the clone? **A:** No; filter by `ls-remote`. _Rationale:_ pruning leaves the commit unreachable, and a lock may still name it.

Resolved Grill Log: behaviour covered by `test/Pudu/PackageSpec.hs` and `test/package-registry.py`.
