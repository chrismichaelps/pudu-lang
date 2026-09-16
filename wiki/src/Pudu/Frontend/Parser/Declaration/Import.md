---
type: module
path: "@root/src/Pudu/Frontend/Parser/Declaration/Import.hs"
fidelity: Active
domain: "[[Pudu Module]]"
subsystem: "[[Frontend]]"
grammar: "[[grammar/haskell]]"
depth_score: 0.64
depth_status: MEDIUM
coupling: 3.0
interface_stability: 1.0
tags: [module, medium]
aliases: [Parser Import]
---

# Parser Import

## Purpose

Parse consecutive absolute module imports, optional uppercase aliases, and explicit non-empty item selections without mixing alias and selection meaning.

## Interface

### Signatures

```haskell
parseImports :: Parser [Located Import]
parseImport :: Parser (Located Import)
```

### Governance

- `import Core.Net`, `import Core.Net as Net`, and `import Core.Net {Client, Error,}` are the three admitted shapes.
- Alias and selection suffixes are mutually exclusive; if both appear, `E1031` preserves the recovered fields but diagnostics prevent validity.
- Selection braces require at least one item; `{}` emits `E1030` at the closing brace.
- Items accept identifiers in source order and one trailing comma.
- Alias casing reuses [[Parser Name]]'s `E1011` uppercase segment rule.
- Consecutive imports and item continuations use [[Parser State]]'s shared budget; exhaustion returns partial syntax with one `E1099` and no synthetic closing-delimiter cascade.

### Linkage

- **Requires:** [[Parser State]], [[Parser Name]], [[Token]], [[Syntax Tree]], [[grammar/pudu]].
- **Consumed by:** the future declaration orchestrator.

## Algorithm

Loop over `import` starters under the shared budget. Parse one module path, select at most one primary suffix, recover a conflicting selection explicitly, and parse comma-separated items with token-progress/completion evidence before requiring `}`.

## Negative Logic (Prohibited Paths)

- No wildcard imports, relative paths, empty selections, alias/selection ambiguity, raw-text symbol construction, name resolution, or unbounded list recursion.

## Edge Cases

- A bare import ends at its module path; a trailing comma is accepted only inside a non-empty selection; missing `}` emits the state-owned `E1001` unless an existing budget failure already explains the unconsumed branch.

## Depth

DEPTH 0.64 (MEDIUM). It hides mutually exclusive suffix grammar, casing reuse, completion-aware recovery, spans, and bounded list traversal behind two operations.

## Grill Log

- **Q:** May alias and selection coexist? **A:** No; diagnose `E1031` while preserving recovered syntax. _Rationale:_ the grammar exposes one unambiguous import binding mode. _Rejected:_ silently accepting both; discarding the second suffix.
- **Q:** Are empty selection braces meaningful? **A:** No; emit `E1030`. _Rationale:_ a bare import already represents no explicit item list. _Rejected:_ two spellings for the same import.
- **Q:** How is long-list recovery total? **A:** Carry explicit closing completion and compare tokens around nested item work. _Rationale:_ `E1099` must not cascade into a false missing brace. _Rejected:_ unconditional closing expectation after budget exhaustion.

## Variants

- Rename and nested-item syntax require a later grammar/semantic slice; this module retains the absolute import contract.

## Referenced by

[[src/Pudu/Frontend/Parser/Declaration/_MOC]] · [[Parser State]] · [[Parser Name]] · [[Token]] · [[Syntax Tree]] · [[Frontend]]
