---
type: handoff
status: IN_REVIEW
issue: 658
aliases: [Ark Layer Delivery]
tags: [handoff, ark, dependencies]
---
# Ark Layer Delivery

Fresh feature/658-ark-layers starts from fetched development c13dd93e. Earlier reviewed work
remains in PRs #653, #655 and #657; their independent branches are preserved. Existing untracked
build products remain untouched. This slice independently validates synthetic engine graphs
while the engine foundation waits for integration.

Role transitions: Architect → Tooling Engineer → Test Engineer → independent Language Architect
and Forensic Guardian. Tooling Engineer owns scripts/ark-layers.mjs and its model; Test Engineer
owns ark-layers.test.mjs and gate/CI registration. Architect owns complete resolved mirrors and
navigation. No implementation begins before these pages. No engine runtime or language changes.

Contract: [[Ark Dependency Layers]] has an explicit fifteen-root catalog, acyclic same-root
composition, strictly descending cross-root imports, shared-utility reverse-edge refusal and
complete source/identity diagnostics. Reuse existing scanner and iterative SCC/depth code.
Only focused model/CLI checks run locally; no full gates.

Evidence: four focused Node groups pass, including all fifteen classifications, deterministic
reports, every refusal family and a 5,000-module same-root chain. Real library scan reports
217 source modules, zero engine modules and zero findings before foundation integration.
Independent Language Architect/implementation and Forensic Guardian reviews pass without
findings; the reviewer independently reran the tests and library scan. No full gates run.

Exact next action: publish this reviewed graph PR, integrate the pending reviewed foundations
when required checks permit, then extend Ark Math/Core under the enforced layer policy.

## Referenced by

[[handoffs/_MOC]] · [[Ark Dependency Layers]] · [[Ark Layer Tests]]
