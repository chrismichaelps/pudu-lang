---
type: module
path: "@root/packages/pudu/v0.1/src/Pudu/Cli/Publish.hs"
fidelity: Active
domain: "[[Pudu Program]]"
subsystem: "[[Tooling]]"
grammar: "[[grammar/haskell]]"
tags: [module, cli, packages, github]
aliases: [Pudu CLI Publish]
---

# Pudu CLI Publish

## Purpose and interface

`pudu login [--token T] [--private]` stores a GitHub token, verified with `GET /user`: from `--token`, from GitHub's OAuth device flow when `PUDU_GITHUB_CLIENT_ID` names an application (`public_repo`, or `repo` with `--private`), or from `gh auth token`. `logout` forgets it; `whoami` names the account. `release <version> [--notes FILE]` requires the manifest version and a clean working tree, runs `pudu check` and `pudu test`, creates the annotated tag `v<version>` (reusing one on this commit, refusing one on another), and pushes it to `origin`; with a token it then creates the GitHub release (an existing one is left alone) and adds the `pudu-package` topic (`packageTopic`), reporting either failure without undoing the tag. `search [words]` lists repositories from GitHub search with the topic. `githubApi` is `PUDU_GITHUB_API` or `https://api.github.com`; `formBody` encodes form fields.

See [[architecture/PACKAGES]] · [[Package GitHubIndex]].

## Grill Log

- **Q:** Publish to a registry? **A:** No; the tag is the release and the topic lists it. _Rationale:_ GitHub is the index.
- **Q:** Require a login to release? **A:** No; only to announce. _Rationale:_ pushing a tag needs git credentials alone; the release and topic are conveniences for readers.
- **Q:** Where does a token come from without an OAuth application? **A:** The GitHub CLI's, when it is signed in. _Rationale:_ one sign-in for both tools. _Rejected:_ asking for a password.

Resolved Grill Log: behaviour covered by `test/package-registry.py`.
