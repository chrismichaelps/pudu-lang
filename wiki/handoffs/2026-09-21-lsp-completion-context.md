---
type: handoff
status: COMPLETE
date: 2026-09-21
issue: 274
tags: [handoff, tooling, lsp]
---

# LSP Completion Context

## Boundary

Issue #274 adds one syntax-directed completion-context query and uses the checked match subject to
limit pattern candidates. It does not change Pudu syntax, typing, diagnostics, executable-module
admission, or the LSP wire protocol.

## Role transition

- **Language/Tooling Architect:** accepted [[Lsp Context]] as the boundary between retained compiler
  products and completion presentation. Resolved choices are syntax traversal over text parsing,
  canonical nominal identity over spelling, conservative pattern coverage, and token-owned
  suppression for comments and quoted literals.
- **Tooling Implementer:** owns `Pudu.Lsp.Context`, `Pudu.Lsp.Completion`, `Pudu.Lsp.Documents`, the
  bounded `Pudu.Lsp.Server` analysis wiring, their mirrors, `ServerSpec`, and the stdio session test.
- **Forensic Guardian:** verify the final diff against this handoff, the four module mirrors, MOCs,
  changelog, focused evidence, and full gates before delivery.

## Accepted behavior

- A match arm offers only variants of its checked subject sum, spelled through the root module's
  actual import. An unguarded wildcard/binding or an irrefutable constructor payload suppresses the
  covered variant; guarded and refutable payload arms do not.
- Sum identity is module-qualified. Generic subject arguments substitute into positional and named
  payload details. Same-spelling variants remain qualified when an unqualified spelling is ambiguous.
- A type position offers lexical type parameters before visible and wired-in types.
- Import positions are read from the lexer's tokens, so `import Std.` and `import Std.Co` are
  answered while the document does not parse. They offer whole module paths from an on-disk catalog
  of the source root, manifest roots, and the standard library ([[Lsp Module Catalog]]), replacing
  the written path. Comments and quoted literals offer no code candidates.
- The compiler keeps a tooling tree (`compileSyntax`) through later-phase errors, so a pattern
  context is found while the match being extended is still non-exhaustive. Ordinary expressions, call arguments, and record initializer values use the
  same context boundary and preserve scope completion.
- Incomplete or unavailable compiler products degrade to conservative empty or ordinary-scope
  answers; they never turn a recovery node into executable semantic evidence.

## Evidence required

- Focused pure-server tests for local and same-spelling sums, coverage, generics/payloads, imported
  sums, type parameters, imports, comments/strings, calls, and record initializers.
- Real stdio requests for the issue's match and generic-return reproductions.
- Optimized build, focused suite, formatter check, and `bash test/gates.sh`.

## Exact next action

None for #274. Lexical scope boundaries continue in #275.

## Referenced by

[[handoffs/_MOC]] · [[Lsp Context]] · [[Lsp Completion]] · [[Lsp Server]]
