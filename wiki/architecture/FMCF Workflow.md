---
type: architecture
tags: [architecture]
aliases: [FMCF Workflow]
---

# FMCF Workflow

## Repository Contract

1. Re-anchor through [[00-INDEX]] and the relevant MOCs.
2. Read [[grammar/haskell]] before Haskell and [[grammar/pudu]] before Pudu examples or fixtures.
3. Define every new language/implementation concept in [[domain/_MOC]].
4. Author and grill a complete mirrored module page before creating or changing `@root/src`.
5. Project the page into code without inventing behavior.
6. Run focused and full verification; reconcile every learned behavior into the page.
7. Update backlinks, MOCs, [[CHANGELOG]], and a handoff when work remains.

## Split Rule

Source files target fewer than 500 lines. A proposed edit exceeding 15% of an existing file triggers responsibility review before implementation.

## Referenced by

[[00-INDEX]] · [[architecture/_MOC]] · [[architecture/LANGUAGE]]
