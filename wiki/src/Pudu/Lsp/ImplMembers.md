---
type: module
path: "@root/src/Pudu/Lsp/ImplMembers.hs"
fidelity: Active
domain: "[[Compilation Artifact]]"
subsystem: "[[Tooling]]"
grammar: "[[grammar/haskell]]"
tags: [module, tooling, lsp]
aliases: [Lsp Impl Members]
---

# Lsp Impl Members

## Purpose and interface

`implMemberCompletions` answers, inside `impl Trait for Type { … }` and outside
every member body, the trait's members the implementation has not written:
each a method snippet with the signature the trait declares, required members
first and defaults marked as overrides. `implementMembersActions` offers one
quick fix per implementation overlapping the request range, writing every
required member with a `panic("not yet implemented")` body before the closing
brace. `canonicalKeys` maps a written type path to the canonical keys the
document can reach it by; record-field completion shares it.

## Invariants

Members come from [[Lsp Shapes]]' trait table, so a local trait, an imported one
and Std's traits answer alike; imported defaults come from the interface's
default set. The trait's parameters are replaced by the implementation's
arguments (`impl Holds[Str]` writes `-> Str`). A member whose header holds the
cursor is the one being typed and is still offered, without repeating a `fn`
already written; a cursor inside a member's body gets ordinary completion.

## Grill Log

- **Q:** Read signatures from the documentation index? **A:** No; it keeps
  types but not parameter names, and a stub needs both.
- **Q:** Leave stub bodies empty? **A:** No; `panic("not yet implemented")`
  checks as any result, so the file keeps compiling while the member is
  filled in.
- **Q:** Offer defaults in the quick fix? **A:** No; only required members.
  Completion offers defaults as overrides.

## References

[[Lsp Completion]] · [[Lsp Code Action]] · [[Lsp Shapes]] · [[src/Pudu/Lsp/_MOC]]
