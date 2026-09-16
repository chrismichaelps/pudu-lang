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
rewritten. Candidate production uses array transformation and flattening rather than repeatedly
copying a growing result array.
