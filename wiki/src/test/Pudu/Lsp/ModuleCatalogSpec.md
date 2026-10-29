---
type: module
path: "@root/test/Pudu/Lsp/ModuleCatalogSpec.hs"
fidelity: Active
aliases: [Lsp Module Catalog Spec]
tags: [module, lsp, test]
---
# LSP Module Catalog Spec

## Purpose and algorithm

Expose named QuickCheck properties for actual moduleCatalog calls over isolated project,
installed package and library trees. Restore PUDU_LIB on every exit. The locked package's
ordinary module remains visible; its fake Std module is absent; the real library module
remains present despite the extra package root. Project-owned Std modules remain visible.
Library-owned ordinary modules stay absent. Catalog output is sorted and unique.

[[Repository Test Runner]] and [[Pudu Test Cabal Manifest]] register this same focused family.
Use temporary source declarations and a local lock without network or package installation.

## Resolved Grill Log

- **Q:** Test the directory walker alone? **A:** No; exercise full root discovery and namespace
  admission, because the defect is the disagreement between ordinary and shipped root lists.
- **Q:** Depend on the host installation's library contents? **A:** No; uniquely named fixtures
  distinguish real library, package-only and project-only declarations.

## Referenced by

[[src/Pudu/Lsp/_MOC]] · [[Lsp Module Catalog]] · [[Repository Test Runner]]
