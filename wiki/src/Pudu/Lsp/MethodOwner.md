---
type: module
path: "@root/src/Pudu/Lsp/MethodOwner.hs"
fidelity: Active
domain: "[[Compilation Artifact]]"
subsystem: "[[Tooling]]"
grammar: "[[grammar/haskell]]"
depth_score: 0.4
depth_status: SHALLOW
tags: [module, shallow, tooling, lsp]
aliases: [Lsp Method Owner]
---

# LSP Method Owner

## Purpose

Name the owners a method is looked up under: the canonical keys the checker files a receiver's
methods by, for a typed value, a written type, or a type parameter. Completion offers what those
owners declare; definition jumps to where they declare it.

## Interface

```haskell
type DeclaredMethod = (Text, Scheme, Span)
receiverOwners  :: Analysis -> [TypeParameter] -> Type -> [Text]
writtenOwners   :: Analysis -> ModuleName -> [Text]
declaredOn      :: Analysis -> Text -> [DeclaredMethod]
traitMembersNamed :: Analysis -> Text -> [DeclaredMethod]
```

## Governance

- A nominal receiver is owned by its own key; an applied type by its head; a reference by its
  target; a `dynamic` trait by the trait; a type parameter by every trait its bounds name in scope.
- A written path names keys the way the module's own imports reach it: a bare name is this
  module's own or a selectively imported one; a qualifier is an alias or a whole-module import's
  qualifier.
- `declaredOn` answers only what the program's modules declared under a key, each with the span of
  its name — for a generated method, the derive that wrote it.
- `traitMembersNamed` answers a trait member a type may inherit as a default, where the type's own
  key declares nothing of that name.

## Algorithm

Peel references and applications to a head; map it to keys; read the analysis's per-key method
table.

## Negative Logic (Prohibited Paths)

- No method is matched by spelling across unrelated owners, except the trait-member fallback, which
  answers only trait declarations.

## Linkage

- **Requires:** [[Lsp Documents]], [[Lsp Context]], [[Type Value]].
- **Consumed by:** [[Lsp Completion]], [[Lsp Definition]].

## Grill Log

- **Q:** Keep owner resolution inside completion? **A:** No. _Rationale:_ definition must look a
  method up under exactly the owners completion offers it from; two copies would drift.
  _Rejected:_ duplicating the owner rules in definition.

## Referenced by

[[src/Pudu/Lsp/_MOC]] · [[Lsp Completion]] · [[Lsp Definition]]
