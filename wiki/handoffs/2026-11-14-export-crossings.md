---
type: handoff
status: ACTIVE
issue: 906
aliases: [Native Export Crossings Delivery]
---

# Native Export Crossings Delivery

Language Architect → Backend Engineer. This partition completes phase 0 of [[Pudu Native]]: exports that carry text, records and `Result`. Backend Engineer → Forensic Guardian review covers [[Backend Export Crossing]] and [[Backend Emit Export]].

## Scope

- Text crosses as `pudu_string`: parameters are checked as UTF-8 and copied into owned Pudu text; results are owned copies the host releases with `pudu_string_release`.
- Records cross as public structs named `pudu_<Name>` with Pudu field names, nested and text members included.
- `Result` returns report 0 for `Ok` and 1 for `Err`, with optional out pointers for each payload.
- Every owned value is released exactly once, and invalid host text stops the call with a located message.

## Landed

[[Backend Export Crossing]] and the export wrappers ([[Backend Emit Export]]): text, records and `Result` cross; the export, embedded and direct groups pass.

## Exact next action

Run test/gates.sh and open the PR for #906; then start phase 1 of [[Pudu Native]] with the counter application.

## Referenced by

[[handoffs/_MOC]] · [[ADR-0031-compiled-native-execution]]
