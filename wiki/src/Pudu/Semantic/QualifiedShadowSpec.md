---
type: module
path: "@root/test/Pudu/Semantic/QualifiedShadowSpec.hs"
fidelity: Active
tags: [module, test, resolution]
aliases: [Qualified Shadow Spec]
---
# Qualified Shadow Spec

Prove loaded namespace/value precedence through real temporary dependency modules. Calls, captured methods, nested closures, fields, sibling blocks and restored aliases run in both evaluator modes with and without folded constants. Compare uncached analysis with cold execution and a fresh cache seeded from collected serialized products. Assert that products were collected. Warning-bearing roots deliberately recheck while dependency products reuse; warning-free namespace controls can reuse their own checked product. Scalar shadows refuse actual member access with exact code/message/help/span; explicit generic paths cannot bypass that refusal. Assert that a value sharing only a trait name has no cross-namespace shadow warning. Preserve qualified record/type construction, unshadowed functions/variants/constants, shared bare interface names, unsafe and compile-time restrictions.

Register through [[Repository Test Runner]] and [[src/pudu-tests-cabal|Pudu Test Manifest]]. Requires [[Compiler Program]], [[Eval Program]] and [[Type Check Rule]]. The test owns temporary source files and restores evaluator selection even on failure.

## Resolved Grill Log

- **Q:** Assert only diagnostic codes or compare evaluators only? **A:** Neither. Assert expected values and exact refusal identity so a shared wrong answer cannot pass.
- **Q:** Treat hidden bare dependency declarations as shadows? **A:** No. Exercise an alias sharing such a name without a local declaration.
- **Q:** Add generic receiver-method syntax implicitly? **A:** No. Explicit nominal selection remains valid; an ordinary receiver follows the existing E3028 refusal.

## Referenced by

[[src/Pudu/Semantic/_MOC]] · [[Qualified Shadow Delivery]]
