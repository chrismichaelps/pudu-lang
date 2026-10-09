---
type: architecture
status: ACTIVE
tags: [application, dependencies, graph]
aliases: [Application Dependency Layers]
---
# Application Dependency Layers

Actual source imports define dependency edges. Strongly connected components identify cycles;
their condensed graph supplies measured structural depth. Architectural layers separately constrain
what a module may depend on. A graph's computed depth cannot authorize an upward architectural edge.

| Layer | Responsibility |
| --- | --- |
| 0 | Ordinary foundation modules and runtime capabilities. |
| 1 | Database driver contract and lifecycle stage contract. |
| 2 | Database mapping and schemas; independent application services. |
| 3 | Database query and frame construction; response and security values; trace delivery. |
| 4 | Database session and query shape; routing. |
| 5 | Database capacity admission policy. |
| 6 | Database pool; application problems and streamed replies. |
| 7 | Database migration and storage composition; server and middleware. |
| 8 | Concrete database connectors. |
| 9 | Application resource and request integration. |
| 10 | Application hosting composition. |

Every specialized module has an explicit catalog entry. A new application, database or server
module without an entry fails validation. Specialized imports descend strictly; imports among
ordinary foundation modules may remain within layer zero, while their cycles remain forbidden.
Foundation dependencies reachable from the framework cannot import specialized services.
The watched-run refresh adapter planned in issue #448 belongs to layer nine.

The gate scans all shipped declarations to validate identities, paths, missing imports and cycles.
Layer enforcement uses the complete transitive closure rooted in application, database and server
modules, including optional services. Reports sort identities and edges deterministically and expose
both structural depth and architectural layer. No file contents, settings or private inputs enter
the report. Source scanning is not a replacement for compiler acceptance.

## Resolved Grill Log

- **Q:** Infer architectural permission from existing imports? **A:** No; the explicit catalog
  prevents a newly introduced dependency from authorizing itself.
- **Q:** Ignore optional framework modules? **A:** No; they are roots too.
- **Q:** Accept a cycle because declarations can be loaded? **A:** No; framework cycles fail the gate.

## Referenced by

[[architecture/_MOC]] · [[Application Layer Gate]] · [[Application Layer Model]] · [[Application Layer Tests]]
