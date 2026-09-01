---
type: module
path: "@root/src/Pudu/Repl.hs"
fidelity: Active
domain: "[[Pudu Program]]"
subsystem: "[[Tooling]]"
grammar: "[[grammar/haskell]]"
depth_score: 0.72
depth_status: MEDIUM
coupling: 6.0
interface_stability: 0.9
tags: [module, medium]
aliases: [Pudu REPL, puduci]
---

# Pudu REPL

## Purpose

Run `puduci`, the interactive session: read program text or a colon command, compile and evaluate it against everything entered so far, and report the value or the diagnostics.

## Interface

### Signatures

```haskell
data ReplOptions = ReplOptions
  { replStyle :: !RenderStyle
  , replInitialLoad :: !(Maybe FilePath)
  }
defaultReplOptions :: ReplOptions
banner :: Text
runRepl :: ReplOptions -> IO ()
```

### Governance

- `:doc` and `:search` read an index built by the session's own compile, so they describe the
  declaration the reader typed a moment ago. A pre-built index could not know about it.
- A submission with no tokens of its own — a `///` line and nothing else — is documentation waiting
  for the declaration it documents, so the prompt keeps reading rather than evaluating nothing.
- Search results at the prompt are capped at a screenful. A prompt is not a results page: past that
  the reader has stopped reading and should refine the query.

- Session settings live in an `IORef` reached through `ReplContext` rather than being threaded as
  a loop parameter: they are prompt state, like the completion snapshot beside them, and a command
  that flips one must be visible to the entry evaluated after it.
- `:set +t` reports the checker's type when there is one and falls back to the value's kind only
  when the checker produced none, so the answer is never less precise than what the session knows.

- The session is named `puduci` and prompts with `puduci> `, continuing with `puduci| `. The banner names the version and points at `:?`, so the first line tells a newcomer how to proceed.
- Every command is a colon command; everything else is program text. Abbreviations resolve to the first command they prefix, so `:q`, `:l`, and `:t` stay stable as commands are added.
- IO stays in this module. Compilation, evaluation, and session state live in [[Repl Session]], which is why the session's behaviour is testable without a terminal.
- An entry that is still open keeps reading. Continuation ends at a closing `}` that balances the entry or at a blank line; the blank line is what lets a form whose next line begins with `|`, `.`, or `?` be entered without a lookahead the prompt cannot perform. `:{` and `:}` bracket a block explicitly.
- Diagnostics are reported against the line the reader typed, never against the generated preamble, using [[Diagnostic Render]]'s interactive configuration.
- Colour is a caller decision passed in from the entry point; the session never inspects the terminal itself.
- The line reader provides editing, history, and completion. History is kept in `.puduci_history` in the reader's home directory, and Tab completion is answered by [[Repl Complete]] from a snapshot of the session's names refreshed after each accepted entry.
- Ctrl-C abandons the line being typed and returns to the prompt with the session untouched, so an interrupt costs a line rather than a session. End of input leaves cleanly.
- The session value stays pure and threaded through the loop; a reference to it exists only so completion can read what the session declared, and completion never writes to it.
- A failed entry changes nothing. The session advances only on acceptance, so a mistake cannot leave a half-defined context behind.
- `:type` is static inspection only. It reports the type recorded by the
  checker, preserves compiler diagnostics for invalid input, and says `no type`
  when the entry has no expression type. It never evaluates the entry and has
  no runtime-shape fallback. A warning is printed and followed by the valid
  static type; only errors stop the answer.

### Linkage

- **Requires:** [[Repl Session]], [[Repl Command]], [[Repl Complete]], [[Repl Outline]], [[Diagnostic Render]], [[Eval Value]], [[Lexer Facade]], [[Parser Block]], [[Parser State]].
- **Consumed by:** the `pudu` executable.

## Algorithm

Print the banner, optionally load a file, then loop: read a line, continue it while it is open, dispatch a command or submit the text to [[Repl Session]], render diagnostics and any value, and repeat until `:quit` or end of input.

## Negative Logic (Prohibited Paths)

- No grammar, evaluation, or resolution logic of its own; no global session state; no terminal detection; no silent recovery that hides a diagnostic; and no command that alters the session as a side effect of inspecting it.
- Static commands never reach the evaluator. In particular, `:type` cannot run
  the expression it describes or replay effects already present in the session.

## Edge Cases

- End of input at the prompt or inside a continuation leaves cleanly rather than hanging or discarding the session without a word.
- `:load` on a file with errors reports them and keeps the previous context, so a broken edit never empties a working session.
- An unknown command names itself and points at `:?`.

## Depth

DEPTH 0.72 (MEDIUM). One entry point hides prompting, continuation, command dispatch, rendering, and the loop's state threading.

## Grill Log

- **Q:** Should the session evaluate entries, or only check them? **A:** Evaluate. _Rationale:_ a session that answers `3` to `1 + 2` is how a language gets exercised; a checker that prints nothing teaches nothing. _Rejected:_ a check-only prompt until typing exists.
- **Q:** Where does session state live? **A:** In [[Repl Session]], threaded through the loop. _Rationale:_ pure state makes the session's behaviour testable without a terminal, and it is what lets a rejected entry leave nothing behind. _Rejected:_ a mutable reference; state hidden in the IO loop.
- **Q:** Where does completion get its names? **A:** From a snapshot refreshed after each accepted entry, not from the compiler on every keystroke. _Rationale:_ Tab must be instant, and the loop has already compiled the session it would otherwise recompile. _Rejected:_ compiling inside the completion callback; a fixed keyword-only list, which would never offer what the reader just defined.
- **Q:** How does a multi-line form end without lookahead? **A:** At a balancing `}` or a blank line. _Rationale:_ brace-terminated forms end naturally, and the blank line covers the leading-`|` and leading-`.` continuations the language admits. _Rejected:_ peeking the next line, which would print a prompt for input that may not be needed; requiring `:{` for every multi-line form.
- **Q:** May `:type` evaluate an entry and discard its value? **A:** No.
  _Rationale:_ effects and runtime failures occur before the value can be
  discarded, which makes a question about code change the program it is
  inspecting. _Rejected:_ ordinary submission with hidden output.

## Variants

- The reader is replaceable without touching the session: an editor front end or a protocol server can drive the same submission call.

## Referenced by

[[src/Pudu/Repl/_MOC]] · [[Repl Session]] · [[Repl Command]] · [[Diagnostic Render]] · [[Evaluator]] · [[Tooling]]
