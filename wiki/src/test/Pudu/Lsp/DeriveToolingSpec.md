---
type: module
path: "@root/test/Pudu/Lsp/DeriveToolingSpec.hs"
fidelity: Active
subsystem: "[[Tooling]]"
grammar: "[[grammar/haskell]]"
tags: [module, test, lsp]
aliases: [Lsp Derive Tooling Spec]
---

# Lsp Derive Tooling Spec

## Coverage

Through the server's request path, on a document defining and requesting a sum derive: definition
on a `derives` entry and on a `derive Tell for` header reaches the trait, and hover names it;
completion after `variant.` and `field.` in the template offers the metadata members, and hover on
`variant` shows `Variant[T]`; hover on the template's member describes it as the derive's.

## Grill Log

- **Q:** Fold these into the method-definition spec? **A:** No; they test the authored view of the
  document, which every cursor feature shares.

## References

[[Lsp Analysis]] · [[src/_MOC]]
