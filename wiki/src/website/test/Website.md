---
type: module
path: "@root/website/src/Test/Website.pudu"
fidelity: Active
tags: [website, tests, regression]
aliases: [website regression suite]
---
# Website Regression Suite

Loads the generated public catalogue and checks ranked search, canonical server-rendered pages,
robots policy, sitemap coverage, favicon metadata, about, donation and repository navigation, copyright,
same-name declaration families, missing-page behavior, and hostile query escaping.

Resolved Grill Log: tests call the pure route renderer rather than opening a socket, so failures
identify website behavior and do not depend on a free local port.
