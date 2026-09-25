---
type: module
path: "@root/website/src/Domain/Library.pudu"
fidelity: Active
tags: [website, domain, api, library]
aliases: [website Domain Library]
---
# Website Domain Library

The standard library arranged the way a reader looks for it: by what a module is for. `SECTIONS` is a
module constant table of `Section { id, title, lead, modules }` — core values, text, numbers,
collections, files and processes, data formats, bytes, networking, applications and databases,
concurrency, interfaces and media, and testing. `SUMMARIES` maps each module a section opens with to
one sentence.

A section lists families, not files. `childrenOf` answers the catalogue modules whose names continue a
listed module and are not listed themselves, so `Std.Http.Server.Route` appears beneath `Std.Http`.
`unplaced` answers catalogue modules no section reaches, which [[website View Documentation]] shows
under Other and the website suite requires to be empty, so a module added to the library without a
place is caught. `Std.Human` sits with text, `Std.Stats` with numbers, `Std.Term` and `Std.Cron`
with the machine and time, `Std.Dotenv` with data formats, `Std.Checksum` with the byte-level hashes,
and `Std.Site` and `Std.Ip` with the web.

Values hold names and sentences only; no HTML.

Resolved Grill Log: grouping by the first name segment alone was rejected, because `Std.Compress.Gzip`
and `Std.Archive.Zip` have no parent module and belong beside the byte-level modules. Per-module
sentences are written here rather than derived from the first documented declaration, whose line
describes that declaration and not the module.
