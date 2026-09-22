---
type: script
path: "@root/website/scripts/generate-packages.mjs"
fidelity: Active
tags: [website, packages, build]
aliases: [Package snapshot generator]
---
# Website Package Snapshot Generator

Builds the package pages' data from the GitHub API: repositories found by `topic:pudu-package`
(public, not archived, with lowercase-safe names), their version tags whose `pudu.toml` names the
package and the tag's version, each release's dependencies from that manifest, notes, author, and time
from the tag's GitHub release (or the tagged commit's time), the latest release's files from its archive
without dot paths or `deps/`, its API catalogue from `pudu doc --json` and `pudu api --json`, and each
owner's profile and avatar. `GITHUB_TOKEN` raises the rate limit; `--api` points at a stand-in.

See [[architecture/PACKAGES]] · [[website Service Packages]].

## Grill Log

- **Q:** Read a registry's documents? **A:** GitHub's API. _Rationale:_ GitHub is the index; there is no registry.

Resolved Grill Log: covered by `test/package-registry.py`.
