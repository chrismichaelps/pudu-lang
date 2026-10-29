---
type: module
path: "@root/test-fixtures/ark/UsesArkHierarchy.pudu"
fidelity: Active
aliases: [Ark Hierarchy Fixture]
tags: [module, ark, test]
---
# Ark Hierarchy Fixture

Compares [[Ark Hierarchy]] lane propagation with scalar [[Ark Transform]] composition on a
three-level tree with a sibling branch and a non-uniform leaf, after a local edit, after
reparenting, after subtree removal, and along a fifty-level chain; checks duplicate and cycle
refusals and bulk pose size. Checks [[Ark Events]] reader cursors, two-update retention and
skipping of dropped events. Run by [[Ark World Gate]]. Prints `ark hierarchy: ok`.

## Referenced by

[[Ark World Gate]]
