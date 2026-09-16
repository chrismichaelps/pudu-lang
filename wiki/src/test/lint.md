---
type: module
path: "@root/test/lint.mjs"
fidelity: Active
domain: "[[Testing]]"
subsystem: "[[architecture/DELIVERY]]"
tags: [module, test, cli, lint]
aliases: [Live Lint Gate]
---

# Live Lint Gate

## Purpose and interface

Given the freshly built `pudu` executable, run the committed typed lint fixture through the actual
CLI. Require non-zero status and four structured safe findings, copy the source into an isolated
directory, apply `--fix`, require empty JSON and zero status, then check and lint the rewritten file.

## Grill Log

- **Q:** Apply fixes to the committed fixture? **A:** No. _Rationale:_ a release gate must be
  repeatable and leave the checkout unchanged. _Accepted:_ an always-cleaned temporary copy.
- **Q:** Trust human text alone? **A:** No. _Rationale:_ editor and CI integrations consume the JSON
  compatibility surface. _Accepted:_ parse and inspect every required field.

## Referenced by

[[Repository Gates]] · [[Pudu CLI Lint]] · [[Redundant Boolean Lint Fixture]]
