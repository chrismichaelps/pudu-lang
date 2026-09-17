---
type: module
path: "@root/src/Pudu/Lsp/Repair.hs"
fidelity: Active
tags: [module, tooling, lsp]
aliases: [Lsp Repair]
---
# LSP Repair

Answers questions about a half-written program from a nearby text that compiles further: the written text with one range removed (or a call closed). `mostComplete` compiles candidates in order and keeps the first that type-checks, else the first that resolved. Offsets before the removed range agree, so a type found there is the one the reader sees. Nothing repaired is stored or reported.

Resolved Grill Log: diagnostics always describe the text as written; a repair only informs completion and signature help.
