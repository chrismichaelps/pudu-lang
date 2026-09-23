---
type: module
path: "@root/website/src/View/Packages/Frame.pudu"
fidelity: Active
tags: [website, packages, view]
aliases: [website View Packages Frame]
---
# Website Package Frame

Shared project banner, avatar, navigation tabs, GitHub star link, and install disclosure. Tickets and Contributions are native tabs backed by the build snapshot; Stars (with a count shortened by `shortCount` as `1.2k`) still opens the repository's GitHub stargazers. The banner identifies the package, includes its description and release, and places the install control near the title. The install panel shows an exact command for the newest available release, version choices, the unversioned command and its 72-hour minimum-age behavior, an import line, and copy controls. It is absent when no installable release exists. Its script enhances native HTML controls. Child source and discussion pages may supply their own canonical address.
On a short viewport, the disclosure summary moves above the scrollable panel and shows Close; its
accessible name describes the toggle in either state.
Package rows and headings show the GitHub account's avatar. They prefer the build's local copy,
then a GitHub-hosted avatar URL. If neither is available, a restrained geometric user silhouette
fills the same square without initials or generated illustration.
The silhouette remains beneath the image until it loads; the small avatar script removes a failed
image to expose the fallback cleanly.
The package script revision advances with the pagination module so browsers discard cached behavior.

See [[architecture/PACKAGES]] · [[website Service Packages]].

## Grill Log

- **Q:** Host tickets and contributions? **A:** Render GitHub's public records as native read-only tabs and link to GitHub for posting and review. _Rationale:_ discovery stays on the package page while the repository retains the conversation. _Rejected:_ a second writable tracker.

- **Q:** What represents an owner when GitHub has no usable avatar? **A:** A neutral user silhouette
  in the site palette. _Rationale:_ it is recognizable at both row and profile sizes without
  inventing account imagery.

Resolved Grill Log: a native disclosure keeps the install instructions available when script is unavailable; only published, non-yanked versions are selectable for new installs. The banner and tabs are original Pudu design, while preserving a clear project hierarchy.
