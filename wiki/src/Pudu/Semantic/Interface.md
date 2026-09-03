---
type: module
path: "@root/src/Pudu/Semantic/Interface.hs"
fidelity: Active
domain: "[[Pudu Program]]"
subsystem: "[[Semantics]]"
grammar: "[[grammar/haskell]]"
depth_score: 0.68
depth_status: MEDIUM
coupling: 4.0
interface_stability: 0.75
tags: [module, medium]
aliases: [Semantic Interface]
---

# Semantic Interface

## Purpose

Expose the names a parsed module makes importable and interpret each import against those exports before lexical resolution walks bodies.

## Interface

### Signatures

```haskell
data ModuleExports
data ExportIndex

moduleExports :: Module -> ModuleExports
exportIndex :: Map ModuleName Module -> ExportIndex
importBindings
  :: ExportIndex
  -> Located Import
  -> ([ImportBinding], [Diagnostic])
```

### Governance

- Exports are indexed by declaring module, namespace, and declared name. The index is built from parsed module declarations before any body is resolved.
- Only `export` declarations enter the index. Implementations are unnamed and are carried by [[Type Interface]], not introduced as lexical bindings.
- An exported foreign block contributes every opaque handle in the type namespace and every foreign function in the value namespace. The block is the visibility boundary: exporting individual members could expose a producer without its release function.
- A selected import from a loaded module must name an exported declaration. A missing or private selection reports `E2013` at the selected item and introduces no placeholder.
- A module or alias import introduces one module binding. Resolution recognizes the qualifier's first segment; later type/value validation is owned by the type interface.
- An import binding records its namespace, local spelling, and span. Declaring identity is preserved by the export/type indexes rather than embedded in this lexical binding. Imports remain private and never re-export.
- The export index is a pure value. Dependency discovery and missing-module `E2014` belong to [[Compiler Program]].
- When the program loader has no authoritative interface because a module is missing or invalid, imports receive opaque placeholders solely to prevent follow-on resolution diagnostics; [[Compiler Program]] already owns the earlier `E2014`/`E2015` failure.

### Linkage

- **Requires:** [[Syntax Tree]], [[Syntax Name]], [[Symbol Model]], [[Diagnostic Model]], [[architecture/SEMANTICS]].
- **Consumed by:** [[Compiler Program]], [[Name Resolution]], [[Resolve Context]], [[Type Interface]].

## Algorithm

Project each parsed declaration with exported visibility into its value/type namespace entries. Interpret a consumer import as either selected bindings or one module binding, validating every selected name and returning deterministic diagnostics in source order.

## Negative Logic (Prohibited Paths)

- No filesystem access, type formation, method selection, body walk, wildcard import, implicit re-export, or basename-only module identity. Opaque placeholders are allowed only when no module interface exists and never for a rejected selection against an existing interface.

## Edge Cases

- A type and value with the same spelling may both be exported because namespaces remain separate.
- A selected import may bring an opaque foreign handle and its functions into the same two namespaces as ordinary declarations; no pointer representation leaks into the lexical interface.
- Selecting a spelling exported in only one namespace introduces only that namespace, unlike the old opaque-import fallback that guessed both.
- Selecting the same item twice remains a same-frame conflict in [[Resolve Context]].
- An empty selection imports no names; a bare or aliased module import introduces only its qualifier. The resolver validates that qualifier's first segment, while later qualified type/value lookup uses [[Type Interface]].

## Depth

DEPTH 0.68 (MEDIUM). It hides export projection, namespace-aware selection, declaring identity, module aliases, and stable import diagnostics behind a small pure API.

## Grill Log

- **Q:** Should imports remain opaque in a program graph? **A:** No. _Rationale:_ loaded modules provide authoritative exports, so guessing both namespaces would discard privacy and identity. _Rejected:_ permanent `ImportOrigin` placeholders in both namespaces.
- **Q:** Does a module import copy all exports into the local scope? **A:** No; it binds one qualifier. _Rationale:_ `import A` and `import A {x}` are deliberately distinct grammar forms. _Rejected:_ wildcard-like unqualified injection.
- **Q:** Who reports a missing source module? **A:** [[Compiler Program]], before interface lookup. _Rationale:_ only the loader knows paths and IO failures. _Rejected:_ fabricating an empty export set and reporting every selection as private.
- **Q:** Are implementations lexical exports? **A:** No. _Rationale:_ implementations have no source name; [[Type Interface]] carries them for trait dispatch after imports establish which traits are in scope. _Rejected:_ synthetic implementation symbols.

## Variants

- Serialized package interfaces may populate the same `ExportIndex` without parsed source.

## Referenced by

[[src/Pudu/Semantic/_MOC]] · [[Compiler Program]] · [[Name Resolution]] · [[Resolve Context]] · [[Type Interface]]
