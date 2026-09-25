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

The generator delegates GitHub access to [[Package snapshot GitHub client]] (conditional requests and
counts), discovery to [[Package topic discovery]] (date slices past the 1,000-result cap), and reuse to
[[Package snapshot cache]] (`--cache`, default `<out>.cache`). A package is **reused** when its version
tags (names and commits) and GitHub release list match the previous build: its releases, README,
declarations, files, and catalogue are carried over, and stars, forks, and discussions are refreshed.
Otherwise it is **refreshed**, and only tags not seen before are read. When GitHub's remaining limit
reaches `PUDU_GITHUB_RESERVE` (default 250), a changed package with a previous entry is **deferred**:
it keeps that entry until the next build. A new package with no entry is skipped with a warning. An
owner's avatar is carried over while GitHub reports the same image URL. The build ends with one line:
refreshed, reused, and deferred counts, requests made, answers not modified, and archives downloaded.

See [[architecture/PACKAGES]] · [[website Service Packages]].

## Grill Log

- **Q:** Read a registry's documents? **A:** GitHub's API. _Rationale:_ GitHub is the index; there is no registry.
- **Q:** Rebuild every package on every deploy? **A:** No. _Rationale:_ at about `2·tags + 8` requests
  a package, a few hundred packages exhaust GitHub's hourly limit; unchanged packages cost a few
  conditional reads instead.
- **Q:** Fail a build that runs low on rate limit? **A:** No; defer changed packages. _Rationale:_ a
  slightly stale entry is better than no deployment, and the next build finishes the refresh.

Resolved Grill Log: covered by `test/package-registry.py`.
