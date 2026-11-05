---
type: module
path: "@root/lib/Ark/Render/Graph.pudu"
fidelity: Active
aliases: [Ark Frame Graph]
tags: [module, ark, render]
---
# Ark Frame Graph

## Purpose and interface

Declared passes over named resources. `pass(name, reads, writes, run)` with `run: fn(Target) ->
Option[Target]`; `graph()`, `add`, `exported(graph, resource)`; `compile -> Result[Compiled,
GraphError]` resolves each read to its latest earlier writer, refuses `DuplicatePass`,
`ReadBeforeWrite(pass, resource)` and `NothingExported`, culls passes that no exported resource
depends on, and reports each resource's first and last live pass for aliasing. `order(compiled)`
and `execute(compiled, target) -> Option[Target]` runs live passes in order.

## Grill Log

- **Q:** Execute passes in declaration order without analysis? **A:** No; declared reads and
  writes are what let unused work be culled and transient resources share memory.

## Referenced by

[[src/Ark/_MOC]] · [[Ark Render Fixture]]
