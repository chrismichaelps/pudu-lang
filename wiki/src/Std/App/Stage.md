---
type: module
path: "@root/lib/Std/App/Stage.pudu"
fidelity: Active
domain: "[[Standard Library]]"
subsystem: "[[architecture/STDLIB]]"
tags: [module, stdlib, application, lifecycle]
aliases: [Std App Stage]
---
# Std App Stage

## Purpose

Name one application resource and pair the action that starts it with the action that stops it.

## Interface

`Stage` contains a name, a fallible start action, and a fallible stop action. `create` builds the
record without running either action. [[Std App]] decides ordering, rollback, and error reporting.

## Governance and algorithm

A stage is an inert value. Construction performs no I/O, so an application can assemble and
inspect its lifecycle before any resource opens. Both actions return `Result[(), Str]`; this keeps
resource-specific text at the boundary while the application layer adds the stage name and order.

## Grill Log

- **Q:** Should `create` start the resource immediately? **A:** No. _Rationale:_ construction must
  remain deterministic and testable; [[Std App]] owns lifecycle order and rollback. _Rejected:_
  hidden startup during record construction.
- **Q:** Can a re-export make the module's own `Stage` constructor resolve as a different type?
  **A:** No. _Rationale:_ the declaring module's local type must win over aliases introduced by a
  consumer. _Rejected:_ changing this factory to compensate for stale or context-dependent name
  resolution.

## Dependencies and consumers

[[Std App]] · [[Std App Database]]

## Referenced by

[[src/Std/_MOC]] · [[architecture/STDLIB]]

Resolved Grill Log: keep the public module and type names stable; the compiler's layered-alias
regression fixture protects local constructor resolution.
