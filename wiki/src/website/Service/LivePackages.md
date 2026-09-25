---
type: module
path: "@root/website/src/Service/LivePackages.pudu"
fidelity: Active
tags: [website, packages, service, github]
aliases: [website Service LivePackages]
---
# Website Service LivePackages

Lays GitHub over the build snapshot ([[website Service Packages]]) so the function lists a package
within minutes of its publication, with no redeploy.

- One search, `topic:pudu-package` sorted by last update (100 per page), finds new and changed
  repositories; everything older is the snapshot's. Remembered 120 s fresh, a day stale.
- A repository the snapshot lacks enters only when its newest semver tag holds a `pudu.toml` whose
  `package.name` is `@owner/repo` and whose `package.version` is that tag's version — the build's
  admission rule. Owner and repository must be lower-case hyphenated slugs; private and archived
  repositories are skipped. Its README at that tag becomes its overview; its owner gains a profile.
- A repository the snapshot has takes GitHub's stars, forks, and open issues. When it was pushed
  after its latest snapshot release, its tags are read; a newer valid release becomes latest and
  the latest-release `files` and `catalog` are dropped with the old release, while its compact
  declarations stay searchable until the next build.
- At most eight repositories have tags read per rebuild; tags are remembered 300 s, files at a tag an hour.
- The merged index is memoized for 30 s. `View.live` says whether GitHub contributed.
- Without a listing from GitHub (outage, rate limit, malformed answer) the snapshot is returned unchanged.

See [[website Service LiveSource]] · [[website Web Dynamic]] · [[architecture/PACKAGES]] · [[src/website/_MOC]].

## Grill Log

- **Q:** Probe an unknown `@owner/repo` when a reader asks for it? **A:** No; only repositories the
  topic search lists can have a page. _Rationale:_ arbitrary paths cannot turn readers into GitHub
  requests, and the topic is what publishing means. _Rejected:_ per-path repository probes.
- **Q:** Page through every topic result at runtime? **A:** No; one page of the most recently updated.
  _Rationale:_ a new publication is the most recent update; the build covers the long tail.
- **Q:** Which release date does a live release carry? **A:** The repository's last push.
  _Rationale:_ it is the nearest date the search states without another request per tag.

Resolved Grill Log: live data only adds to or refreshes the snapshot; it never removes a snapshot
project, and a failure anywhere yields exactly the snapshot.
