---
type: decision
status: ACCEPTED
date: 2026-10-27
aliases: [ADR-0025-integrated-engine-namespace]
tags: [decision, ark, modules]
---
# ADR-0025: An Integrated Engine Namespace

## Decision and compatibility

Reserve the exact root `Ark` for the shipped engine library, using the same project-first,
library-fallback resolution as `Std`. A dependency package may provide neither namespace.
Previously `import Ark.Math` could resolve from an installed package; now it selects the
project's declaration or the shipped declaration. Existing projects using a package-owned
Ark root must rename that dependency namespace or deliberately provide the project-owned module.
`Arks.Math` remains ordinary. No syntax changes or new diagnostic identities are introduced;
an absent shipped module retains E2014 and an incompatible value retains E3001.

This is a breaking resolution change, semantic draft 2.0.0, separate from compiler versioning.
Math is provisional and no stable lifecycle promise applies before Ark lifecycle policy exists.
Interpreted fixtures, project-shadow and package-exclusion checks establish resolution behavior;
bundle/archive checks preserve the module closure. Native execution remains open and this
decision introduces no C11 engine emission. Review date: 2026-10-27.

## Resolved Grill Log

- **Q:** Allow packages to replace Ark implicitly? **A:** No; one integrated distribution must
  have one explicit owner. Visible project modules retain the same override rule as Std.
- **Q:** Reserve prefixes such as Arks? **A:** No; compare the complete first module segment.

## Referenced by

[[decisions/_MOC]] · [[Ark Engine]] · [[architecture/SEMANTICS]] · [[Compiler Library]]
