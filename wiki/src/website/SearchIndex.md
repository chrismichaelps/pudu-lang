---
type: module
path: "@root/website/src/SearchIndex.pudu"
fidelity: Active
tags: [website, search, build]
aliases: [website Search Index]
---
# Website Search Index

Builds the compact dynamic-search catalogue from the validated public API catalogue. It writes only
language version, module, declaration name, kind, signature, and summary, escaping record separators
so arbitrary documentation text cannot change the format.

Resolved Grill Log: this is a derived deployment artifact, never a second API source. Generation must
round-trip every searchable entry and fail before deployment when writing the index fails.
