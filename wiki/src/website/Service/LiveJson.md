---
type: module
path: "@root/website/src/Service/LiveJson.pudu"
fidelity: Active
tags: [website, json, github]
aliases: [website Service LiveJson]
---
# Website Service LiveJson

Readers for GitHub's documents: a field that is missing or of another type reads as empty (text, zero,
false, no items) rather than failing, and `at` follows a path of fields such as
`commit.committer.date`. GitHub adds and omits fields freely, and one odd field must not fail a page.

Resolved Grill Log: lenient reading is confined to this module, so every live reader agrees on what
an absent field means. _Rejected:_ strict decoding, which turns an API change into an outage.

## Referenced by

[[website Service LiveIndex]] · [[website Service LiveRelease]] · [[website/_MOC]]
