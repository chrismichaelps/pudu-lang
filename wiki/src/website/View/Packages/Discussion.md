---
type: module
path: "@root/website/src/View/Packages/Discussion.pudu"
fidelity: Active
tags: [website, packages, view, discussion]
aliases: [website View Packages Discussion]
---
# Website Package Discussion

Renders project Tickets and Contributions tabs from the build-time GitHub snapshot. Lists show the latest public records with title, number, state, author, date, and labels. Detail pages render the source body through the safe Markdown body view, including an initial heading, and link to GitHub for posting or review. Unknown numbers do not get a detail page.
The list serves a bounded page and exposes numbered follow-up pages for scroll loading and direct
navigation without script.
An empty discussion list has an explanatory banner; populated lists and the next-page control
expose loaded and loading states respectively.

See [[architecture/PACKAGES]] · [[website Service Packages]] · [[website View Packages Frame]].

## Grill Log

- **Q:** Mirror comments and allow writing on the website? **A:** No; the snapshot is read-only and links to the original GitHub conversation. _Rationale:_ GitHub retains permissions, review state, notifications, and the complete history.
- **Q:** Render issue and pull request text as HTML from GitHub? **A:** No; parse their Markdown through the site's safe subset. _Rationale:_ a public repository owner controls that text.

Resolved Grill Log: lists and details share the project frame and canonical paths; the snapshot's bound is visible to readers as “recent” records.
