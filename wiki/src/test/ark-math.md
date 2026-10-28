---
type: module
path: "@root/test/ark-math.mjs"
fidelity: Active
aliases: [Ark Math Gate]
tags: [module, ark, test]
---
# Ark Math Gate

## Purpose and algorithm

Run [[Ark Math Fixture]] with the supplied compiler and repository library root. Require zero
exit and exact output; check formatting of the module and fixture. In a private temporary source
root, compile a caller passing Float32 to binary64 `vec3`; require failure and E3001. Delete
temporary files on every exit. This verifies shipping-root resolution without engine packaging.
Temporary project/library trees prove project overrides and exact namespace matching. Installed
package roots cannot supply a missing Ark module. Package the actual compiler, inspect the archive
for Ark/Math and Std/Math, extract it, and run the fixture through its packaged binary/library.
Isolated packager calls with mocked process/version lookup refuse an empty Std or Ark tree
before creating an archive, preserving the required-namespace admission rule.
[[Repository Gates]] invokes this after the fresh optimized compiler build.

## Resolved Grill Log

- **Q:** Accept any rejected client? **A:** No; inspect E3001 so unresolved imports cannot pass.
- **Q:** Build through native C emission? **A:** No; this gate establishes interpreted conformance only.

## Referenced by

[[src/Ark/_MOC]] · [[Ark Math Fixture]] · [[Repository Gates]]
