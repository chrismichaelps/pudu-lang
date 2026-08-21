---
type: moc
tags: [moc, module]
---

# Declaration Parser Modules

- [[Parser Import]] — absolute module imports, aliases, and explicit item selections.
- Future bounded partitions add binding, function, block, and declaration-orchestration modules.

The submodules accept narrow parser capabilities and never import the declaration orchestrator, preventing the recursive block/expression/declaration knot from becoming a Haskell module cycle.

## Referenced by

[[src/Pudu/Frontend/Parser/_MOC]] · [[Frontend]]
