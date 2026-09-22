---
type: module
path: "@root/registry/src/Service/Publish.pudu"
fidelity: Active
tags: [registry, publishing, github]
aliases: [registry Service Publish]
---
# Registry Service Publish

`push` registers or refreshes a project from its repository's default branch; `release` publishes the commit a tag names (`v<version>` when none is given): the token must be able to push to the repository, the commit archive is fetched from GitHub and read by `Archive.fromCommitArchive`, its `pudu.toml` must name the package and the version, the version must be new and not lower than a release on the same major line, and the files are repacked by `Archive.pack`, whose digest is the checksum. A release records its tag, commit, and publisher; the project takes its visibility from the repository and falls back to the repository's description and topics. `yank`, `configure` (description), and `remove` (delete without releases, otherwise unlist) need the same permission. Refusals carry an HTTP status.

See [[architecture/PACKAGES]] · [[src/registry/_MOC]].

## Grill Log

- **Q:** Keep GitHub's archive as the release? **A:** Repack it. _Rationale:_ GitHub's archives carry a commit comment and are not promised to be byte-stable; the registry's canonical archive is. _Rejected:_ storing GitHub's bytes.
- **Q:** Delete a released project? **A:** Unlist it. _Rationale:_ existing locks must keep installing.

Resolved Grill Log: behaviour covered by `registry/src/Test/Registry.pudu` and `test/package-registry.py`.
