---
type: module
path: "@root/website/src/Service/Catalog.pudu"
fidelity: Active
tags: [website, service, catalogue]
aliases: [website Service Catalog]
---
# Website Service Catalog

Reads and validates the generated `pudu doc --json` catalogue, lists modules, and performs exact
module and symbol-family lookup. A family retains every declaration sharing one public module,
kind, and name, including trait declarations and concrete implementations. The outer document must carry schema version `1` and a language version;
the application keeps the language version so pages and diagnostics can identify their source.
It also reads the line-oriented search index generated from that validated catalogue. The search form
retains exactly the fields ranking and result rendering consume, with escaped separators restored by
a bounded parser.

Resolved Grill Log: reject an unknown outer schema before reading declarations, skip malformed
individual records only after the outer document is valid, and fail when no usable declarations
remain. Transform and flatten records through array primitives so catalogue startup stays linear.
The compact reader rejects malformed headers or records instead of silently serving a partial index.
