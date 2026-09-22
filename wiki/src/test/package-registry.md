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
damaged cached checkout, the website's snapshot from the API, and logout.

See [[architecture/PACKAGES]] · [[Package GitHubIndex]].

## Grill Log

Resolved Grill Log: git runs for real; only GitHub's HTTP API is stood in, so resolution and integrity are tested as shipped.
