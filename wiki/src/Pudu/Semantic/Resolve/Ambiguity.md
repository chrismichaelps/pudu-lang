---
type: module
path: "@root/packages/pudu/v0.1/src/Pudu/Semantic/Resolve/Ambiguity.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
aliases: [Resolve Ambiguity]
tags: [module, resolution]
---
# Resolve Ambiguity

## Purpose and interface

Own imported candidate registration by the introduced lexical symbol, local and
imported alias classification, and positioned E2012 construction. Expose
recordImportedVariants, isVariantAlias, rejectAmbiguous and rejectImportedPath,
with PathUse distinguishing ValuePath and QualifierPath. ImportedVariant retains
declaration spans and the export-index type-head fact.
The module is internal to resolution; it performs no source loading or typing.

## Algorithm and invariants

Use the invocation-local State and Scope's innermost lookup. Registration binds
an import's suffix-to-declaration-spans map to its selected SymbolId. A nearer
ordinary symbol has no registry entry. Local aliases use the existing owner pool;
selected imported aliases use the empty suffix. Qualified checks use nonempty
suffix prefixes only, preventing duplicate bare-reference diagnostics. All
candidate spans become Related notes; the original use span remains primary.
Append diagnostics to the normal reversed accumulator for Context's final sort.
Normal single-name resolution reuses the selected symbol instead of searching
scope again. Candidate maps are immutable and no runtime metadata is generated.

## Negative logic and edge cases

Never infer an owner from a scheme, select the first/last candidate, diagnose
unused imported labels, change reflection restrictions, or traverse ordinary
value fields as module export paths. A type-qualified suffix that names an owner
is distinct from an ambiguous exported bare label. Opaque imports have no pool.

## Resolved Grill Log

Move the existing local ambiguity policy out of Context before adding imported
policy. This is one cohesive candidate/diagnostic boundary, preserving the pure
state model while keeping Context below 500 lines. Direct state access is limited
to the candidate registry, its read-only lexical selection and diagnostic append.
No scope mutation, symbol allocation or accumulator freezing belongs here.
See [[Imported Variant Delivery]].

## Referenced by

[[Resolve Context]] · [[Resolve Canonical]] · [[Name Resolution]] · [[Resolve State]] · [[Pudu Package Manifest]] · [[src/Pudu/Semantic/_MOC]]

Resolved type-head control: imported candidates retain an export-index TypeSpace flag; PathUse preserves C.First.Chosen qualification without admitting ambiguous value fields. Syntactically named member paths preserve head spans. See [[Imported Variant Delivery]].
