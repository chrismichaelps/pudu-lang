---
type: module
path: "@root/src/Pudu/Frontend/Parser/Name.hs"
fidelity: Active
domain: "[[Pudu Module]]"
subsystem: "[[Frontend]]"
grammar: "[[grammar/haskell]]"
depth_score: 0.57
depth_status: MEDIUM
coupling: 1.0
interface_stability: 1.0
tags: [module, medium]
aliases: [Parser Name]
---

# Parser Name

## Purpose

Parse located identifiers and non-empty dotted module/name paths with clear casing diagnostics.

## Interface

### Signatures

```haskell
parseModuleName :: Parser (Located ModuleName)
parseNamePath :: Parser (Located (NonEmpty Text))
expectUpperIdentifier :: Text -> Parser (Located Text)
```

### Governance

- Module segments begin with an uppercase Unicode letter; violation is E1011 but structure is preserved.
- Standalone module aliases reuse the same E1011 uppercase rule through `expectUpperIdentifier`.
- Dots require a following identifier; no trailing empty segment.

### Linkage

- **Requires:** [[Parser State]], [[Syntax Name]], [[Syntax Located]].
- **Consumed by:** current [[Parser Type]] and [[Parser Import]], plus future declaration modules.

## Algorithm

Expect one identifier, loop over dot+identifier, merge first/last spans, and validate module casing.

## Negative Logic (Prohibited Paths)

- No import/name resolution or keyword-as-name recovery.

## Edge Cases

- One segment succeeds; trailing dot diagnoses at the missing segment.

## Depth

DEPTH 0.57 (MEDIUM). Centralizes repeated dotted-path and casing behavior.

## Grill Log

- **Q:** Enforce module-path/file match here? **A:** No; parser lacks manifest path. _Rationale:_ Tooling/Semantics owns cross-input validation. _Rejected:_ hidden filesystem access.

## Variants

- Value paths reuse the segmented parser without uppercase validation.

## Referenced by

[[src/Pudu/Frontend/Parser/_MOC]] · [[Parser State]] · [[Parser Type]] · [[Parser Import]] · [[Frontend]]
