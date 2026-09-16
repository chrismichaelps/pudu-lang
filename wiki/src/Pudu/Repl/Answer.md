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
browseModule :: ReplOptions -> Session -> Maybe Text -> IO ()
renderReplValue :: Bool -> Value -> Text
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
- `browseModule` renders module exports grouped by category (Constants, Types, Traits, Functions)
  with documentation summaries when a module name is provided, falling back to local session
  context declarations when no argument is passed.
- `renderReplValue` formats values safely: when truncation is enabled, collections beyond 50 elements
  and strings beyond 500 characters display structured previews with item counts rather than
  flooding the terminal.
- `showState` takes the settings it reads rather than the whole loop context.
  Taking the context would have made this module import the loop and the loop
  import this, for one `IORef`.
- `:show bindings` displays only statement bindings (`sessionStatements session`) with `bind    `
  prefix, isolating variable assignments from `:show declarations` (functions, types, traits)
  and `:show imports`. Full context is inspected via `:context`.
- `:type` is a compiler question. It uses [[Repl Session]]'s type probe and
  never enters the evaluator: a valid expression reports its static type, an
  invalid expression reports the compiler diagnostics against the submitted
  source, and an entry with no expression type reports `no type`. Warnings are
  rendered before the valid type; only an error makes the type answer
  unavailable.

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
- **Q:** Should any diagnostic suppress the type? **A:** No; warnings are
  reported and the valid type follows. _Rationale:_ warnings do not make a
  program ill-typed, and hiding the type turns successful inspection into a
  diagnostic-only command. _Rejected:_ treating a non-empty diagnostic list as
  failure.
- **Q:** Why group `:browse` exports with doc comments? **A:** Presenting categorized
  constants, types, traits, and functions with short doc summaries gives immediate discovery
  without requiring separate `:doc` lookups for each name. _Rationale:_ interactive productivity. _Rejected:_ raw flat name dumps.
- **Q:** Why format `:set +s` timing with auto-scaling units and heap allocation tracking? **A:** Raw scientific floats like `1.247e-3 secs` are difficult to scan. Scaled units (`µs`, `ms`, `s`) and heap allocation metrics provide immediate profiling insights. _Rationale:_ human-centered interactive metrics. _Rejected:_ unformatted floating point seconds.
- **Q:** Should `:show bindings` display declarations or imports? **A:** No. _Rationale:_ `:show bindings` is specifically intended for inspecting active variable bindings; `:show declarations` and `:show imports` separately inspect declared symbols and imported modules, while `:context` displays all three together. _Rejected:_ conflating `:show bindings` with `:context`.

## Referenced by

[[src/Pudu/Repl/_MOC]] · [[Pudu REPL]] · [[2026-08-31-static-repl-inspection]]
