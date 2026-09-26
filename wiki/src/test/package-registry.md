---
type: script
path: "@root/test/package-registry.py"
fidelity: Active
tags: [packages, github, e2e]
aliases: [Package end-to-end suite]
---
# Package End-to-End Suite

Real bare git repositories reached through `PUDU_GITHUB_URL=file://…`, and a stand-in for the GitHub
REST API (`PUDU_GITHUB_API`): the account behind a token, topics, releases, search by topic, tags,
contents, commits, and archives. It drives release without and with a login (tag, push, GitHub
release, topic), search, install under the minimum release age, a tag whose manifest gives another
version, the locked commit and tree digest, warm and offline installs with the repository unreachable,
a force-moved tag, update and upgrade, a deleted tag with and without a lock, a missing repository, a
damaged cached checkout, the website's snapshot from the API, a release that names its modules outside
the package root while leaving `Main.pudu` unreported (and a release inside its root that names
none), and logout.
The stand-in serves issues and pull requests separately; the snapshot check proves pull requests do
not leak into Tickets, merged contributions retain their state, and labels are copied.
It checks that full discussion records live outside the compact project index and contribution
links use GitHub's singular `/pull/` detail path.
The stand-in also serves a profile PNG and checks that the snapshot stores the GitHub image locally
and records its source URL.
The stand-in answers with ETags and `304 Not Modified`, understands `created:` ranges in search, and
records every request. After the first snapshot, the suite checks the incremental cases:
- A second build reuses the unchanged package: no archive and no manifest reads, with not-modified
  answers.
- A reused package whose snapshot lost its declaration search facts rebuilds its API catalogue from
  the carried files, without fetching the archive again.
- A starved budget (`PUDU_GITHUB_RESERVE` above the reported limit) keeps the previous release
  instead of failing.
- A new `v1.2.0` tag refreshes the package and reads only that tag's manifest.

See [[architecture/PACKAGES]] · [[Package GitHubIndex]] · [[Package install suite]].

## Grill Log

Resolved Grill Log: git runs for real; only GitHub's HTTP API is stood in, so resolution and integrity are tested as shipped.
