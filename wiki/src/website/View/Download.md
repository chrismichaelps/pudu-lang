---
type: module
path: "@root/website/src/View/Download.pudu"
fidelity: Active
tags: [website, view, download]
aliases: [website View Download]
---
# Website Download View

Renders the current release's download page with the shared page banner, platform cards, archive checksums, a copyable verification command, and links to release notes and documentation. Release facts come from [[website Service Releases]].

## Grill Log

- **Q:** Put release metadata in a separate title section? **A:** No; keep the version and pre-release notice inside the page banner. _Rationale:_ the page identifies the offered release before listing archives.

Resolved Grill Log: retain the visible archive checksum and source-owned release metadata; the view only arranges it.
