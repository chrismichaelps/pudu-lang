---
type: test
path: "@root/website/src/Test/LivePages.pudu"
fidelity: Active
tags: [website, packages, test]
aliases: [website live pages suite]
---
# Website Live Pages Suite

Renders package pages through the function against the stand-in GitHub of [[website live stand]]:
a new package's overview and dated releases, the listing and the owner's profile, an unlisted package
answering a briefly cached 404 that is not indexed, the snapshot served when GitHub is unavailable, a
snapshot release's source and API catalogue, a missing file, and the prerender leaving package pages
to the function. CI runs it with the other website suites.

Resolved Grill Log: pages are rendered through the same routes the function serves, so the suite
checks what a reader receives, headers included.

## Referenced by

[[website/_MOC]]
