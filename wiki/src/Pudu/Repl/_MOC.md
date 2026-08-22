---
type: moc
tags: [moc, module]
---

# REPL Module Map

- [[Pudu REPL]] — the `puduci` loop, prompting, continuation, and command dispatch.
- [[Repl Session]] — session state, entry classification, buffer assembly, and compilation.
- [[Repl Command]] — the closed colon-command vocabulary and its abbreviations.
- [[Repl Complete]] — what completes at the cursor: commands, filenames, or names in scope.
- [[Repl Outline]] — compact structural rendering for `:ast`.

Dependency direction: Command/Outline → Session → Repl. Only [[Pudu REPL]] performs IO.

## Referenced by

[[src/Pudu/_MOC]] · [[Tooling]]
