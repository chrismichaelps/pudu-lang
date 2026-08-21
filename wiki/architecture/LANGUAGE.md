---
type: architecture
tags: [architecture]
aliases: [Architecture Language]
---

# Architecture Language

## Module

- **Definition:** A unit with an interface and a hidden implementation.
- **Canonical name:** Module.
- **Not:** An arbitrary helper split with no behavior-hiding value.
- **Example:** [[Lexer]] hides Unicode traversal, trivia, numeric validation, and token span construction behind one scan operation.

## Interface

- **Definition:** Everything a caller must know to use a module correctly, including invariants, failures, ordering, and side effects.
- **Not:** Only a Haskell type signature.

## Implementation

- **Definition:** The private algorithm and representation that fulfill a module interface.
- **Not:** Behavior callers must reproduce or sequence manually.

## Depth

- **Definition:** The ratio of useful behavior exposed to interface knowledge required.
- **Deep:** Hides substantial policy and mechanics behind a narrow stable contract.
- **Shallow:** Renames or forwards behavior while leaving callers to understand the mechanics.
- **Deletion test:** Removing a deep module makes callers more complicated; removing a shallow module mostly moves unchanged complexity.

## Seam

- **Definition:** A boundary where independently varying production adapters or external systems justify isolation.
- **Canonical classes:** BACKBONE, CRITICAL, EXPLORATORY, INTERNAL.
- **Not:** Every boundary between functions or compiler phases.

## Locality

- **Definition:** The degree to which knowledge and change remain within the owning subsystem.

## Deepening

- **Definition:** Redesigning a module or seam to hide more relevant complexity behind a simpler interface.
- **Not:** Adding layers, interfaces, or files without measurable caller simplification.

## Compiler Pipeline

- **Definition:** The ordered, explicit transformations from [[Source Text]] to [[Compilation Artifact]] or [[Execution Result]].
- **Invariant:** Each phase consumes the preceding phase's owned representation and emits either a value or ordered [[Diagnostic]] values.

## Referenced by

[[00-INDEX]] · [[architecture/_MOC]] · [[architecture/OVERVIEW]] · [[FMCF Workflow]]
