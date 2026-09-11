---
type: module
path: "@root/website/src/Service/Search.pudu"
fidelity: Active
tags: [website, service, search]
aliases: [website Service Search]
---
# Website Service Search

Ranks case-insensitive matches across exact name, name prefix, module, signature, and documentation,
then returns a bounded stable result list.

Resolved Grill Log: exact and prefix name matches outrank prose matches; empty queries return no hits.
Candidate production uses array transformation and flattening rather than repeatedly copying a
growing result array.
