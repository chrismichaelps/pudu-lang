---
type: module
path: "@root/test/Pudu/Derive/CatalogueSpec.hs"
fidelity: Active
subsystem: "[[Semantics]]"
grammar: "[[grammar/haskell]]"
tags: [module, derive, tests]
aliases: [Derive Catalogue Spec]
---

# Derive Catalogue Spec

## Purpose and interface

`catalogueProperties` parses independent module snapshots and tests the actual
canonical catalogue. It does not claim executable request integration.

## Evidence and invariants

Qualified/selected/aliased imports select one canonical trait. Generic inline
requests retain target binders; external requests through a transparent target
alias retain its concrete application. Record and Sum strategies coexist.
Duplicate strategy pairs across modules, duplicate alias requests, invalid trait
applications and nonaggregate/unsaturated targets produce located refusals.
Private strategies remain unavailable outside their defining module.
Definition admission cases assert one generic body diagnostic despite multiple
requests, ignore ordinary bodies at this early boundary, preserve local trait
defaults and refuse to construct a validated candidate after definition errors.

## Grill Log

- **Q:** Test written spelling instead of canonical results? **A:** Assert formed
  full applications and selected defining modules. _Rejected:_ tests that only
  count syntax nodes or imply graph delivery from catalogue admission.
- **Q:** Leave the spec unregistered? **A:** Register in both the manifest and
  repository runner; all outcomes enter aggregate exit status.

## Linkage and references

Requires [[Derive Catalogue]], [[Compiler Pipeline]] and [[Source]]. Referenced
by [[src/_MOC]] · [[Repository Test Runner]] · [[Pudu Test Cabal Manifest]].
