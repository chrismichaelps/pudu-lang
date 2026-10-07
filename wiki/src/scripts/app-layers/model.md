---
type: module
path: "@root/scripts/app-layers/model.mjs"
fidelity: Active
tags: [tooling, application, graph]
aliases: [Application Layer Model]
---
# Application Layer Model

## Purpose and interface

Pure functions scan Pudu module/import declarations and validate their graph against
[[Application Dependency Layers]]. Reuse the existing iterative [[Dependency Layer Model]]
for strongly connected components and computed structural depth.

## Algorithm

Mask nested block comments, line comments and escaped quoted literals while preserving newlines.
Read only the declaration/import prefix; a body cannot invent imports. Reject missing or repeated
module headers, duplicate graph identities and unresolved imports. Preserve all source identities.
Select the complete transitive specialized dependency closure. Refuse unclassified specialized
modules and imports that fail the explicit direction policy. Sort reports and findings.

## Resolved Grill Log

- **Q:** Use recursive graph traversal? **A:** No; explicit stacks handle long chains.
- **Q:** Hide unresolved imports as external edges? **A:** No; every shipped import must resolve.
- **Q:** Allow a new specialized module to default to foundation? **A:** No; fail without classification.

## Referenced by

[[Application Layer Gate]] · [[Application Layer Tests]] · [[Application Dependency Layers]]
