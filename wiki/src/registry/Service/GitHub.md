---
type: module
path: "@root/registry/src/Service/GitHub.pudu"
fidelity: Active
tags: [registry, github]
aliases: [registry Service GitHub]
---
# Registry Service GitHub

`GitHub` is the record of what the registry asks GitHub: `user` (whose token), `repository` (a repository and whether the token can push, `None` when it cannot see it), `commit` (a tag, branch, or commit to its full id), `archive` (a commit's `.tar.gz`, up to `ARCHIVE_LIMIT`), and `profile` (a user or organization). `live api permitted` answers from GitHub's REST API with `Std.Http.Client`, permitting only the hosts named (a local stand-in); tests pass a fake record.

See [[architecture/PACKAGES]] · [[src/registry/_MOC]].

## Grill Log

- **Q:** Count stars and issues? **A:** Copy `stargazers_count`, `forks_count`, and `open_issues_count` into the project at push and release. _Rationale:_ package pages link to GitHub for issues, pull requests, and stars, and show counts without asking GitHub per page. Verified against the live API (`octocat/hello-world`, `jqlang/jq` at `jq-1.7.1`, through the archive redirect).

- **Q:** Call GitHub directly from the services? **A:** Through a record of functions. _Rationale:_ the suite runs without a network, and the end-to-end script points `live` at a stand-in. _Rejected:_ a module of direct calls.

Resolved Grill Log: behaviour covered by `registry/src/Test/Registry.pudu` and `test/package-registry.py`.
