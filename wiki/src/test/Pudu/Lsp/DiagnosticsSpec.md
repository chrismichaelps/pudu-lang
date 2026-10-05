---
type: module
path: "@root/test/Pudu/Lsp/DiagnosticsSpec.hs"
fidelity: Active
subsystem: "[[Tooling]]"
grammar: "[[grammar/haskell]]"
tags: [module, test, lsp]
aliases: [Lsp Diagnostics Spec]
---

# Lsp Diagnostics Spec

## Coverage

A type error's help is a `help:` line of its own. An unmet derive field bound is published at the
field with the `derives` request as a related location in the same file, and no placed note is
repeated in the message. An imported module's error is published at the import line as
`Faulty: …` with its own location as related information, while that module's shadowing warning is
not published on the importer. An empty `derives` at the end of its line is reported on that line,
not on the next declaration.

## Grill Log

- **Q:** Drive these through the server loop? **A:** No; publishing is a pure function of one
  analysis, so the spec reads that function's output for overlaid programs, which needs no client.

## References

[[Lsp Diagnostics]] · [[src/_MOC]]
