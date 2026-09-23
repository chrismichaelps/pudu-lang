---
type: module
path: "@root/website/src/Service/Search.pudu"
fidelity: Active
tags: [website, service, search]
aliases: [website Service Search]
---
# Website Service Search

Parses each request through [[website Domain Search]], rejects candidates outside explicit module or
kind scope, requires every ordinary term, compares normalized Pudu type shapes, and returns a bounded
stable result list. Exact module-leaf intent precedes unrelated name matches so `List` exposes the
complete current `Std.List` surface.

Resolved Grill Log: exact module, qualified-name, exact-name, prefix, token, type, and prose bands are
distinct; filters never add candidates; empty queries return no hits; Pudu argument order is never
rewritten.

The catalogue is searched through an `Index` prepared once, when the site or the function loads:
each entry's name, module, qualified name, module leaf, and signature lowered, its signature
normalised as a type, and its documentation joined and lowered. A query compares against those,
so it lowers nothing per entry. The index is kept in qualified-name order, the tie-break every
ranking ends with, and a score takes one of a few values, so hits are taken score by score,
highest first, in index order: no hit is compared with another. `find` prepares an index for a
single search; the site and the function hold theirs in `Site.search` and `Dynamic.search`.

Resolved Grill Log: an index per catalogue, not per request. _Rationale:_ lowering three thousand
names, signatures, and documentation blocks for every query was nearly all a search cost; on the
local server a query with no hits went from 113 to 63 ms and a broad one from 574 to 176 ms, with
every ranking unchanged. _Rejected:_ sorting all hits by score and name per query.
