---
type: module
path: "@root/test/Pudu/Semantic/QualifiedImportSpec.hs"
fidelity: Active
tags: [module, test, resolution]
aliases: [Qualified Import Spec]
---
# Qualified Import Spec

Prove that only a selected import binds exported names unqualified (#545). A real temporary `Lib.Pages` module exports `show(Str, Int)`, a non-prelude `render`, and an `unsafe fn display`. Successes: under `import Lib.Pages as Pages` and plain `import Lib.Pages`, the prelude `show(3)` and `display(3)` keep their prelude types and the module's functions answer through their qualifier, with expected values in both evaluator modes with and without folded constants. A selection `{show}` deliberately binds the module's `show` unqualified. Refusals with exact codes: the selected `show(3)` is an arity error (E3003, E3001); an unselected export reached bare is unresolved (E2010); the qualified unsafe export outside an unsafe block is still refused (E3023) while the prelude `display` is not. The issue's own program is a success case with output `count 3 x`.

Register through [[Repository Test Runner]] and [[src/pudu-tests-cabal|Pudu Test Manifest]]. Requires [[Compiler Program]] and [[Eval Program]]. The test owns its temporary sources and restores evaluator selection even on failure.

## Resolved Grill Log

- **Q:** Check types only? **A:** No. Run the programs, because the evaluator binds imports on its own and both must agree on which `show` a call reaches.
- **Q:** Use a fresh name for the export? **A:** No. The defect only appears where an export shares a prelude name the resolver already accepts, so the library reuses `show` and `display`.
- **Q:** Treat the selected `{show}` arity error as a regression? **A:** No. Selection is the one form that binds a bare name, and shadowing the prelude there is what the program asked for.

## Referenced by

[[src/Pudu/Semantic/_MOC]] · [[Type Check Install]]
