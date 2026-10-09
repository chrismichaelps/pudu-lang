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

Classify [[Std Db Challenge]] above wire preparation and below [[Std Db Session]]. Resolved Grill Log: its byte/text admission depends only on foundation modules and the existing protocol reader.

## Bounded pool admission (#468)

[[Std Db Admission]] occupies a dedicated layer between sessions and pool ownership. Higher architectural layers shift together, preserving strict descending imports. Classification remains explicit and cannot be inferred from existing source edges.

Resolved Grill Log: a policy boundary that imports sessions must descend from the pool rather than share either layer.

## Integrated Database boundaries (#478)

The catalog retains challenge at four, session at five, capacity admission at six, pool at seven and hosting at eleven. Resolved Grill Log: integrating independently added boundaries shifts higher layers together; the catalog itself already represents both safeguards and requires no change.
