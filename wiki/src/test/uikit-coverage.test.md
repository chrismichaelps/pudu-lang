---
type: module
path: "@root/test/uikit-coverage.test.mjs"
fidelity: Active
aliases: [UIKit Coverage Tests]
---
# UIKit Coverage Tests

## Purpose and interface

Node test runner checks [[UIKit Coverage Inventory]] against small literal header texts: direct and transitive subclasses, generic and protocol-qualified declarations, categories ignored, controls kept out of views, the none trait excluded, whole-identifier matching against host text, sorted output, literal rendered rows, marker errors, byte preservation and idempotence. No SDK or compiler is needed.

## Resolved Grill Log

- **Q:** Test against the installed SDK? **A:** No; its contents change with every Xcode. Literal headers keep expectations exact, and [[iOS Simulator CI]] runs the real check.

## Dependencies and consumers

[[UIKit Coverage Inventory]] · [[iOS Simulator CI]]

## Referenced by

[[src/_MOC]]
