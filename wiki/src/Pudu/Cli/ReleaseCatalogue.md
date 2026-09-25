---
type: module
path: "@root/packages/pudu/v0.1/src/Pudu/Cli/ReleaseCatalogue.hs"
fidelity: Active
tags: [cli, release, packages, docs]
aliases: [Cli ReleaseCatalogue]
---
# Cli ReleaseCatalogue

The API reference a release carries. `pudu release` attaches it to the GitHub release as
`pudu-api.json`, and the website's Docs tab reads it for a release published after the site's last
build ([[website Service LiveFiles]]).

`releaseCatalogue executable root` runs the given `pudu` over the project's Pudu sources outside
`test/` and `tests/` (dot paths and the top-level `deps/` are already absent from the tree
`treeFiles` lists): `doc --json` for what is documented, `api --json` for what is exported.
`normalizeCatalogue` keeps the documented declarations that are exported, once per module, kind,
name, and signature, sorted, under schema 1 and the compiler's language version: the document the
website's build writes for a package.

## Negative logic

- A private declaration is never in the reference, however well documented.
- A project with no sources, or a `doc`/`api` run that fails, attaches nothing; the release goes on
  and says why on stderr.

## Grill Log

- **Q:** Build the reference in the website instead? **A:** No. _Rationale:_ the website's function
  cannot compile a package it has never seen, and the publisher's own compiler is the authority on
  what it exports. _Rejected:_ compiling packages inside the website's function.
- **Q:** Why the same shape as the build's catalogue? **A:** So one parser reads both, and a package's
  Docs tab looks the same whether the build or the release produced it.

## Referenced by

[[Pudu CLI Publish]] · [[website Service LiveFiles]] · [[src/Pudu/_MOC]]
