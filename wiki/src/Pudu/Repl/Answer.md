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
reportEntry :: ReplOptions -> ReplSettings -> EntryResult -> Int -> IO ()
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
- `:type` reports the static type when the checker recorded one for the entry
  and the runtime shape otherwise, which is what `function` means when it
  appears — a fallback, not an answer.

### Linkage

- **Consumed by:** [[Pudu REPL]].

## Referenced by

[[src/Pudu/Repl/_MOC]] · [[Pudu REPL]]
