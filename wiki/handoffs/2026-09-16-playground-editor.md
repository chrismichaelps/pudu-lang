---
type: handoff
status: ACTIVE
issue: 239
tags: [handoff, website, playground, lsp]
---

# Playground Editor

## Objective

Make the website playground a working editor backed by the language server, and let the deployed site
run programs.

## Ownership and roles

1. **Website Implementer:** [[Website Playground Script]], [[Website Playground View]],
   [[Website Playground Routes]], the playground services, and the stylesheet.
2. **Compiler Implementer:** [[LSP Repair]], [[LSP Completion]], [[LSP SignatureHelp]],
   [[Eval Confinement]], and `pudu run`'s output streams.
3. **Validation:** the Cabal suite, the website suites, the LSP session scripts, and a browser pass over
   run, format, completion, signature help, diagnostics, and examples.

## State

- Confined runs refuse host effects with `E7027`; all six playground examples run unchanged confined.
- The deployment runs programs inside the function with `confined` isolation.

## Next action

Verify the preview deployment's run and assist endpoints, then promote it to production.
