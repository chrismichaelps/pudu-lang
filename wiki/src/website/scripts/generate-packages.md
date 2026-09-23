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
It also copies up to 100 most recently updated public issues (excluding pull requests) and 100 pull
requests per package, including their bodies, state, author, dates, labels, and GitHub URLs. GitHub
remains the place to write and browse older history.
Discussion records are written to `discussions/@owner/repo.json` for static pages rather than
inflating the compact project index used by the search function.
The generated project document also carries a compact declaration search index, while full API
catalogues remain static page inputs.

See [[architecture/PACKAGES]] · [[website Service Packages]].

## Grill Log

- **Q:** Read a registry's documents? **A:** GitHub's API. _Rationale:_ GitHub is the index; there is no registry.

Resolved Grill Log: covered by `test/package-registry.py`.
