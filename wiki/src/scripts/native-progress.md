---
type: module
path: "@root/scripts/native-progress.mjs"
fidelity: Active
aliases: [Native Progress Generator]
---
# Native Progress Generator

## Purpose and interface

Read the exact Coverage ledger table in [[Native Emission Coverage]] and render
the single native-progress marker block in [[Repository README]]. Node core APIs
only. CLI accepts --write or --check, resolves repository files from the script
location, and fails without modifying files when input is invalid. Export pure
coverage/render/update functions for [[Native Progress Tests]].

## Contract and failure behavior

Implemented, Partial and Pending states may carry parenthesized issue references.
Only Implemented counts; duplicate areas, unknown states, malformed/empty tables
and missing/duplicate/reversed README markers fail. Percentage is floor(100 *
complete / total); the 20-cell bar fills floor(20 * complete / total) cells.
Zero and full completion render exactly 0% and 100%. Preserve all bytes outside
the block. --check fails on stale output; --write is idempotent.

## Resolved Grill Log

- **Q:** Estimate partial credit? **A:** No; it creates an unauditable second ledger.
- **Q:** Infer completion from passing tests? **A:** No; tests validate admitted surfaces only.
- **Q:** Silently skip an unknown row? **A:** No; fail before publishing a misleading total.

## Dependencies and consumers

[[Native Emission Coverage]] · [[Repository README]] · [[Native Progress Workflow]]

## Referenced by

[[src/_MOC]] · [[Native Progress Tests]]
