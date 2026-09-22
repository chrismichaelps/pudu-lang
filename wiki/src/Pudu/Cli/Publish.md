---
type: module
path: "@root/packages/pudu/v0.1/src/Pudu/Cli/Publish.hs"
fidelity: Active
domain: "[[Pudu Program]]"
subsystem: "[[Tooling]]"
grammar: "[[grammar/haskell]]"
tags: [module, cli, packages, registry, github]
aliases: [Pudu CLI Publish]
---

# Pudu CLI Publish

## Purpose and interface

`pudu login [--private] [--token T] [--registry URL]` runs GitHub's OAuth device flow with the client id from the registry's `/api/v1/config` (scope `repo` with `--private`, none otherwise), prints GitHub's page and code, polls GitHub (slowing down when asked), confirms the token with the registry's `whoami`, and stores it; `--token` stores a GitHub token directly. `logout` forgets it, `whoami` names the account, `push` registers or refreshes the project from its repository, and `release <version> [--notes FILE]` requires the manifest version to match and a clean working tree, runs `pudu check` and `pudu test`, creates the annotated tag `v<version>` (reusing one already on this commit, refusing one on another), pushes it to `origin`, and asks the registry to publish it. `formBody` encodes form fields.

See [[architecture/PACKAGES]].

## Grill Log

- **Q:** Release a working tree with changes? **A:** No. _Rationale:_ the release must be exactly the tagged commit on GitHub. _Rejected:_ packing the working tree.
- **Q:** Ask for the `repo` scope by default? **A:** Only with `--private`. _Rationale:_ it grants write access to every repository; public packages need none.

Resolved Grill Log: behaviour covered by `test/Pudu/PackageSpec.hs` and `test/package-registry.py`.
