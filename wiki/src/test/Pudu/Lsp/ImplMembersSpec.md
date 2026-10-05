---
type: module
path: "@root/test/Pudu/Lsp/ImplMembersSpec.hs"
fidelity: Active
subsystem: "[[Tooling]]"
grammar: "[[grammar/haskell]]"
tags: [module, test, lsp]
aliases: [Lsp Impl Members Spec]
---

# Lsp Impl Members Spec

## Coverage

Completion in an empty implementation offers every member, a default as an
override, signatures with type parameters and `where` clauses; a written
member is not offered again; a half-typed `fn ` is completed without repeating
`fn` and with the trait's argument substituted; an imported Std trait's members
are offered; a member body gets ordinary completion. The quick fix inserts
exactly the required members' stubs.

## Grill Log

- **Q:** Extend the server spec? **A:** No; it is already large, so the
  behavior has a spec of its own through the same request path.

## References

[[Lsp Impl Members]] · [[src/_MOC]]
