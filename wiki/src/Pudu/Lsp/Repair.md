---
type: module
path: "@root/src/Pudu/Lsp/Repair.hs"
fidelity: Active
domain: "[[Compilation Artifact]]"
subsystem: "[[Tooling]]"
grammar: "[[grammar/haskell]]"
depth_score: 0.5
depth_status: MEDIUM
tags: [module, medium, tooling, lsp]
aliases: [Lsp Repair]
---

# LSP Repair

## Purpose

Answer questions about a half-written program from a nearby text that compiles further. Nothing
repaired is stored or reported: diagnostics always describe the text as written, and a repair only
informs completion and signature help.

## Interface

```haskell
data Repair = Repair { repairText :: Text, repairAgreesUntil :: Int }
withoutRange     :: Text -> Int -> Int -> Repair
closedPrefix     :: [Token] -> Text -> Int -> Repair
closedPrefixWith :: Text -> [Token] -> Text -> Int -> Repair
elsewhereBlanked :: Analysis -> Int -> Maybe Text
lineBounds       :: Text -> Int -> (Int, Int)
mostComplete     :: (Text -> IO Analysis) -> (Analysis -> Bool) -> Analysis -> Int -> [Repair] -> IO (Analysis, Int)
```

### Governance

- Every candidate keeps the written text's offsets up to the point it agrees until, so a fact read
  from it before that point is at the reader's position.
- `withoutRange` leaves one range out: the member being written, the word, the line.
- `closedPrefix` ends the text at the cursor and closes every bracket open there, read from the
  lexer's tokens. It is what makes an unclosed function or `match` parse; `closedPrefixWith` first
  writes filler at the cursor, such as a whole placeholder arm (`case _ => panic("")`) in place of
  an unfinished one.
- `elsewhereBlanked` replaces every top-level declaration holding an error, other than the one
  holding the cursor, with spaces (line breaks kept), found through the recovered tree. Offsets are
  unchanged everywhere, so a syntax error in another function no longer hides every fact in this
  one.
- `mostComplete` compiles candidates in order and takes the first that answers the request's
  question — the receiver was typed, the match subject was typed — not merely the first with some
  types. Failing that it keeps the first that resolved, else the written analysis. A candidate
  whose text an earlier one already had is not compiled again.

### Linkage

- **Requires:** [[Lsp Documents]], [[Token]], [[Syntax Tree]], [[Diagnostic Model]].
- **Consumed by:** [[Lsp Completion]], [[Lsp Signature Help]].

## Negative Logic (Prohibited Paths)

- Do not store a repaired analysis or publish its diagnostics.
- Do not read an offset from a candidate beyond where it agrees with the written text.
- Do not accept a candidate because it type-checked when the requested fact is still unknown.

## Grill Log

- **Q:** Why close brackets rather than delete more text? **A:** An editor types inside unclosed
  constructs, and no deletion near the cursor closes them. _Rationale:_ ending at the cursor keeps
  everything before it — bindings, subject, receiver — at its offsets. _Rejected:_ ever larger
  deletions, which cannot restore a missing closing brace.
- **Q:** Why blank broken declarations instead of deleting them? **A:** Deleting shifts every later
  offset. _Rationale:_ spaces keep the mapping exact. _Rejected:_ removal with offset translation.

## Referenced by

[[src/Pudu/Lsp/_MOC]] · [[Lsp Completion]] · [[Lsp Signature Help]]
