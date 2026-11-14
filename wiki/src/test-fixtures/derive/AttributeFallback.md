---
type: module
path: "@root/test-fixtures/derive/AttributeFallback.pudu"
fidelity: Active
aliases: [Attribute Fallback Fixture]
tags: [module, test, derive]
---
# Attribute Fallback Fixture

A record derive reads `@min`, `@max` and `@label` through `attributeOr` with a negated-literal
fallback, an arithmetic fallback and a name fallback, for one field that has every attribute and
one that has none. The program answers the folded values and must compile with no diagnostics:
an effect-free fallback the attribute replaces leaves no unused statement for W3004.

## Referenced by

[[Derive Library Spec]] · [[Derive Record Residualizer]]
