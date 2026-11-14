---
type: module
path: "@root/test/Pudu/Semantic/VariantNamespaceSpec.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
tags: [module, test, resolution]
aliases: [Variant Namespace Properties]
---
# Variant Namespace Properties

## Purpose and interface

variantNamespaceProperties :: [(String, IO Property)] proves local variant
namespace admission and diagnostic provenance through runCompile. Registered in
[[Name Resolution Spec]] and [[Pudu Test Cabal Manifest]].

## Algorithm and invariants

Compile qualified same-labelled constructors from distinct owners. Compile a
nearer value shadow of an ambiguous variant through real public resolver
scope operations; uppercase source parameter names are intentionally invalid. Assert one E2012 at a bare use with
both distinct candidate locations, and E2001 with the first span for a repeated
variant within one owner. Keep ordinary function/type duplicate refusals.
Every error span is nonempty and candidate spans precede the offending use.
Loaded execution, caches and evaluator parity belong to [[Sum Owner Gate]].

## Negative logic

No mocked resolver state, dropped diagnostics or expectation changes masking an
unrelated typing refusal. These are resolution laws, not timing thresholds.

## Resolved Grill Log

Keep new logic outside the existing long resolution coordinator while executing
it through the same real runner. Source input and structured diagnostics prove
observable policy independently of candidate storage. See [[Variant Namespace Delivery]].

## Referenced by

[[src/Pudu/Semantic/_MOC]] · [[Variant Namespace Delivery]] · [[Name Resolution Spec]]

## Qualified head identity (#766)

Add a known type qualifier that is also an ambiguous variant label; qualified construction succeeds and a bare use still refuses.

Resolved Grill Log: an already qualified path must not be refused as a bare variant. Only an alias yields to a known type; ordinary values and import privacy retain their lookup. See [[Variant Namespace Delivery]].

## Imported variant candidates (#775)

Add authoritative export-index resolution tests with exact selected/module-member E2012 use spans and all candidate spans in both declaration orders; use real resolver scopes to prove nearer values win. Keep duplicate and isolated-resolution controls.

Resolved Grill Log: preserve complete declaring-owner ambiguity at uses across imports, lexical shadows and generated syntax. See [[Imported Variant Delivery]].

Resolved type-head control: imported candidates retain an export-index TypeSpace flag; PathUse preserves C.First.Chosen qualification without admitting ambiguous value fields. Syntactically named member paths preserve head spans. See [[Imported Variant Delivery]].
