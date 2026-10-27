---
type: handoff
status: ACTIVE
issue: 486
aliases: [Native Core Contracts Delivery]
---
# Native Core Contracts Delivery

Language Architect → Backend Engineer → Test Engineer → Forensic Guardian
self-audit. Ownership: Core.hs, CoreSpec, Cabal/test registration and matching
vault pages. This dev-based review partition projects existing Core declarations
from the completion branch. No sub-agents; independent review remains pending.
The implementation checkout and its work are preserved separately.

Registering model contracts does not expose native execution. Keep #486 open;
the existing oversized/stacked PR #487 is background context. Later partitions
must publish diagnostics, runtime, lowering, emission, toolchain and CLI/tests.
Do not merge without required validation and independent review.

GHC 9.14.1 -Werror typechecked the dev checkout's model, test and three source
dependencies. The canonical-owner/rendering property passes, and both Cabal
manifest checks report no warnings/errors. Full optimized CI and independent
review remain pending; this partition must stay draft until those are resolved.

Exact next action: open the dev-targeted draft PR, then publish the independent
native diagnostic vocabulary partition before runtime/lowering integration.

## Referenced by

[[handoffs/_MOC]] · [[Pudu Core IR Module]]
