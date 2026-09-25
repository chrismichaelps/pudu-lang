---
type: module
path: "@root/website/src/Service/LiveIndex.pudu"
fidelity: Active
tags: [website, packages, github]
aliases: [website Service LiveIndex]
---
# Website Service LiveIndex

Reads GitHub's `topic:pudu-package` search, most recently updated first, a hundred to a page and at
most ten pages (GitHub's own ceiling). `search` answers the repositories and whether the listing is
**complete**: no page was marked incomplete and the distinct repositories read reach the total GitHub
stated. Only a complete listing lets [[website Service LivePackages]] conclude that a package absent
from it has left the topic; a listing cut short concludes nothing. `None` when the first page is unknown.

Resolved Grill Log: completeness is proven from GitHub's own counts rather than assumed from a page
count, because a repository updated while the pages are read moves between pages and would otherwise
look removed. _Rejected:_ hiding a package on any search that omits it.

## Referenced by

[[website Service LivePackages]] · [[website/_MOC]]
