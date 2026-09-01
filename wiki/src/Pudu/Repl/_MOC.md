---
type: moc
tags: [moc, module]
---

# REPL Module Map

- [[Repl Input]] — when an entry at the prompt is finished, decided over real tokens.
- [[Pudu REPL]] — the `puduci` loop, prompting, continuation, and command dispatch.
- [[Repl Answer]] — terminal presentation for inspection commands and submissions.
- [[Repl Session]] — session state, entry classification, buffer assembly, and compilation.
- [[Repl Command]] — the closed colon-command vocabulary and its abbreviations.
- [[Repl Complete]] — what completes at the cursor: commands, filenames, or names in scope.
- [[Repl Describe]] — what the session knows about a name, for `:info`, `:kind`, and `:instances`.
- [[Repl Outline]] — compact structural rendering for `:ast`.

Dependency direction: Command/Outline/Describe/Complete support Session and
Answer; Answer reads Session; [[Pudu REPL]] coordinates them. Terminal IO is
owned by Answer and [[Pudu REPL]], never by Session.

## Referenced by

[[src/Pudu/_MOC]] · [[Tooling]]
