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

Documentation contributes to a term's score through its summary line alone. A declaration's full
reference text names the types, neighbours, and examples it discusses, so scoring every line would
rank a page that merely mentions a term beside the page that defines it. The summary is also the
only documentation the compact runtime index carries, so ranking on it keeps the deployed search
and the local one from answering differently — a parity the website fixture asserts directly over
several queries.
