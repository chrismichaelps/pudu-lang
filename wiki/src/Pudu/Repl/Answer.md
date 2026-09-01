---
type: module
path: "@root/src/Pudu/Repl/Answer.hs"
fidelity: Active
domain: "[[Pudu REPL]]"
subsystem: "[[Tooling]]"
grammar: "[[grammar/haskell]]"
depth_score: 0.3
depth_status: SHALLOW
coupling: 2.0
interface_stability: 0.85
tags: [module, shallow]
aliases: [Repl Answer]
---

# Repl Answer

## Purpose

Answer a colon command on screen.

## Interface

```haskell
showHelp   :: IO ()
showState  :: IORef ReplSettings -> Session -> Text -> IO [Text]
showType   :: ReplOptions -> Session -> Text -> IO ()
showTokens :: Text -> IO ()
showAst    :: ReplOptions -> Text -> IO ()
performLoad :: ReplOptions -> Session -> FilePath -> IO Session
reportEntry :: ReplOptions -> ReplSettings -> EntryResult -> IO ()
```

### Governance

- **Every one of these takes a session and answers with text; none of them
  changes anything.** That is what lets them be a module rather than part of the
  loop — inspecting a session cannot alter it, and a command that reported
  something while quietly advancing the session would be the worst kind of
  surprise.
- `showState` takes the settings it reads rather than the whole loop context.
  Taking the context would have made this module import the loop and the loop
  import this, for one `IORef`.
- `:type` is a compiler question. It uses [[Repl Session]]'s type probe and
  never enters the evaluator: a valid expression reports its static type, an
  invalid expression reports the compiler diagnostics against the submitted
  source, and an entry with no expression type reports `no type`.

### Linkage

- **Consumed by:** [[Pudu REPL]].

## Negative Logic (Prohibited Paths)

- An inspection command must not call `submitEntry`. Discarding an evaluated
  value cannot undo IO, mutation, failure, or any effect replayed from the
  session buffer.

## Grill Log

- **Q:** Can `:type` reuse ordinary submission and ignore its value? **A:** No.
  _Rationale:_ evaluation has already happened by the time a value can be
  ignored, so `:type print("message")` would print and a runtime failure would
  replace the static answer. _Rejected:_ evaluation followed by value
  suppression or a runtime-shape fallback.

## Referenced by

[[src/Pudu/Repl/_MOC]] · [[Pudu REPL]]
