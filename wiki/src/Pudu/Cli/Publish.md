---
type: module
path: "@root/packages/pudu/v0.1/src/Pudu/Cli/Publish.hs"
fidelity: Active
domain: "[[Pudu Program]]"
subsystem: "[[Tooling]]"
grammar: "[[grammar/haskell]]"
tags: [module, cli, packages, registry]
aliases: [Pudu CLI Publish]
---

# Pudu CLI Publish

## Purpose and interface

`pudu login [--token T] [--registry URL]` (device pairing: prints the page and code, polls until approved), `logout`, `whoami`, `push [--private]`, and `release <version> [--notes FILE] [--private]`, which requires the manifest version to match, runs `pudu check` on the source modules and `pudu test` on `test/` or `tests/`, packs the project, and uploads it as multipart form data. `multipart` builds the body.

See [[architecture/PACKAGES]].

## Grill Log

- **Q:** Release without running the tests? **A:** No. _Rationale:_ a release is immutable. _Rejected:_ a skip flag in phase 2.

Resolved Grill Log: behaviour covered by `test/Pudu/PackageSpec.hs` and `test/package-registry.py`.
