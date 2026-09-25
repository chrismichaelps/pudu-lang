---
type: module
path: "@root/website/src/Service/LiveDiscussions.pudu"
fidelity: Active
tags: [website, packages, github]
aliases: [website Service LiveDiscussions]
---
# Website Service LiveDiscussions

A package's Tickets and Contributions tabs as GitHub has them now: the hundred most recently updated
issues (pull requests left out) or pull requests, each shaped as the build's `Discussion` record —
title and body clipped as the build clips them, author, state (`merged` for a merged pull request),
dates, comment count, up to twelve labels, and the conversation's GitHub address. Remembered with the
`conversation` freshness (a minute fresh, a day stale). `None` when GitHub cannot answer, and
[[website Service LivePackages]] then keeps the snapshot's conversations.

`pathOf` reads a repository's `owner/name` from its GitHub address and answers empty for any other.

Resolved Grill Log: conversations are read live for every package, known ones included, because they
change by the minute and belong to no release. _Rejected:_ reading them only for packages the build
has not seen, which left known packages' tabs a build behind.

## Referenced by

[[website Service LivePackages]] · [[website live pages suite]] · [[website/_MOC]]
