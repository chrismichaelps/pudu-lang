---
type: module
path: "@root/src/Pudu/Repl/Complete.hs"
fidelity: Active
domain: "[[Pudu Program]]"
subsystem: "[[Tooling]]"
grammar: "[[grammar/haskell]]"
depth_score: 0.4
depth_status: MEDIUM
coupling: 3.0
interface_stability: 0.9
tags: [module, medium]
aliases: [Repl Complete]
---

# Repl Complete

## Purpose

Decide what completes at the cursor: a colon command, a filename, or a name the session can see.

## Interface

### Signatures

```haskell
data CompletionSource = CompletionSource { sourceSessionNames :: ![Text] }
completionsFor :: CompletionSource -> Text -> Text -> [Text]
wantsFilename :: Text -> Bool
isNameCharacter :: Char -> Bool
keywordNames :: [Text]
```

### Governance

- Completion is a pure function of the text before the cursor, the word under it, and the names the session holds. It performs no IO, which is why it is testable without a terminal.
- A word that starts the line with `:` completes commands; a `:` anywhere else is ordinary text and completes nothing.
- Filenames are wanted only after a command that takes one, and only once a space follows it. The caller performs the directory read, because only it may touch the filesystem.
- The name pool is assembled rather than fixed: the closed keyword vocabulary, [[Semantic Prelude]]'s wired-in types, the implicit prelude names, and whatever the session declared or bound. A declaration made at the prompt is therefore completable on the next line.
- Results are sorted and duplicate-free, so the same prefix always offers the same list in the same order.

### Linkage

- **Requires:** [[Repl Command]], [[Semantic Prelude]], [[Token]].
- **Consumed by:** [[Pudu REPL]].

## Algorithm

Classify the cursor position, then filter the appropriate candidate list by the word's prefix and sort what remains.

## Negative Logic (Prohibited Paths)

- No IO, no filesystem access, no evaluation, no ranking heuristics, and no completion of names the session cannot actually see.

## Edge Cases

- An empty word offers the whole pool, which the terminal displays as a candidate list rather than inserting.
- A prefix with no match offers nothing rather than falling back to a wider search.

## Depth

DEPTH 0.40 (MEDIUM). It hides cursor classification and pool assembly behind one call, and keeps both out of the IO loop.

## Grill Log

- **Q:** Should completion query the compiler on every keystroke? **A:** No; the session's names are refreshed after each accepted entry and read from there. _Rationale:_ a Tab press must be instant, and recompiling the session to answer one is work the loop already did. _Rejected:_ compiling inside the completion function.
- **Q:** Should a completed name get a trailing space? **A:** Only a command does. _Rationale:_ a command is followed by an argument, while a function name is usually followed by `(`, and an inserted space would have to be deleted. _Rejected:_ a space after every completion.

## Referenced by

[[src/Pudu/Repl/_MOC]] · [[Pudu REPL]] · [[Repl Command]] · [[Semantic Prelude]]
