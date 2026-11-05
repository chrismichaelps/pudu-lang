---
type: module
path: "@root/test/qualified-variants.mjs"
fidelity: Active
aliases: [Qualified Variant Gate]
tags: [module, semantic, regression, test]
---
# Qualified Variant Gate

Create isolated module clients and check/run them with an explicit compiler. Imported alias and
unaliased Module.Type.Variant paths, local type qualification, generic instantiation, first-class
constructors and matching must preserve the owning nominal type and runtime value. Wrong expected
types require positioned E3001; missing variants, private types, local value shadowing and
named-field variants remain refused. Exact success output and deterministic diagnostic codes
protect the public contract. Delete temporary programs on exit. CI/local gates run the same test.

## Resolved Grill Log

- **Q:** Only test valid constructors? **A:** No; silent ErrorType previously accepted wrong result types.
- **Q:** Accept any rejection? **A:** No; require the expected code and authored source location.
- **Q:** Alter runtime lookup without evidence? **A:** No; run real clients to establish whether it needs a change.

## Referenced by

[[Repository Gates]] · [[Qualified Constructor Delivery]] · [[Type Check Expression]]
