---
type: module
path: "@root/src/Pudu/Lsp/SignatureHelp.hs"
fidelity: Active
domain: "[[Compilation Artifact]]"
subsystem: "[[Tooling]]"
grammar: "[[grammar/haskell]]"
depth_score: 0.4
depth_status: SHALLOW
tags: [module, shallow, tooling, lsp]
aliases: [Lsp Signature Help]
---

# LSP Signature Help

## Purpose

Provide active function/method signatures and current parameter indicators when the user invokes or edits arguments within parentheses.

## Interface

```haskell
signatureHelpAt :: Analysis -> Int -> Json
```

## Governance

- Answers when the cursor is enclosed within argument parentheses of a function or method invocation.
- Determines the active parameter index by counting unnested commas between the opening parenthesis and the cursor.
- Answers `JsonNull` when the cursor is not in an invocation context.

## Algorithm

1. Trace backward from cursor offset to find an unmatched opening parenthesis `(`.
2. Identify the callee identifier immediately preceding the parenthesis.
3. Look up the callee's signature in `analysisProgramIndex` or `analysisResolution`.
4. Count commas at the same nesting depth between `(` and cursor.
5. Construct `SignatureHelp` containing `signatures` with parameter labels and `activeParameter`.

## Negative Logic (Prohibited Paths)

- No signature help inside string literals or comments.
- No guessing signatures for unknown callees.

## Grill Log

- **Q:** How are nested parentheses (e.g. `foo(bar(1, 2), baz)`) handled? **A:** The scanner tracks balanced parentheses, brackets, and quotes so the active parameter corresponds to the correct enclosing call.

## Referenced by

[[src/Pudu/Lsp/_MOC]] · [[Lsp Server]]
