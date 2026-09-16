---
type: module
path: "@root/src/Pudu/Repl/Options.hs"
fidelity: Active
domain: "[[Pudu REPL]]"
subsystem: "[[Tooling]]"
grammar: "[[grammar/haskell]]"
depth_score: 0.3
depth_status: SHALLOW
coupling: 2.0
interface_stability: 0.85
tags: [module, shallow]
aliases: [Repl Options]
---

# Repl Options

## Purpose

Hold what the caller decides before the loop starts, and what the reader turns
on once it has.

## Interface

```haskell
data ReplOptions = ReplOptions { replStyle :: RenderStyle, replInitialLoad :: Maybe FilePath }
data ReplSettings = ReplSettings { settingShowTypes :: Bool, settingShowTiming :: Bool, settingTruncate :: Bool }
```

### Governance

- **Settings are session state, not options the entry point chose**, so they are
  a separate record: `:set types` is something the reader turned on mid-session,
  and `--plain` is something the caller decided before there was a session.
- `settingTruncate` bounds the interactive rendering of large collections and strings to prevent
  terminal buffer overflow and lockups, defaulting to active (`True`) and toggleable via `:set +trunc` / `:unset +trunc`.
- Both are shared by the loop and by the commands that answer on screen, so they
  live apart from both rather than one importing the other.

### Linkage

- **Consumed by:** [[Pudu REPL]].

## Grill Log

- **Q:** Why add output truncation as a configurable setting? **A:** Large collections (10,000+ items)
  freeze terminal emulators when printed unformatted. _Rationale:_ default bounded preview with explicit `:unset +trunc` keeps sessions responsive without preventing full inspection. _Rejected:_ hardcoded truncation without override.

## Referenced by

[[src/Pudu/Repl/_MOC]] · [[Pudu REPL]]
