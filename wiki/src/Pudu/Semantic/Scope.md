---
type: module
path: "@root/src/Pudu/Semantic/Scope.hs"
fidelity: Active
domain: "[[Pudu Program]]"
subsystem: "[[Semantics]]"
grammar: "[[grammar/haskell]]"
depth_score: 0.5
depth_status: MEDIUM
coupling: 2.0
interface_stability: 1.0
tags: [module, medium]
aliases: [Scope Model]
---

# Scope Model

## Purpose

Own the lexical scope stack: ordered frames of namespaced bindings with innermost-first lookup and explicit conflict reporting.

## Interface

### Signatures

```haskell
data Scope
data ScopeStack
emptyStack :: ScopeStack
pushScope :: ScopeStack -> ScopeStack
popScope :: ScopeStack -> ScopeStack
declareSymbol :: Symbol -> ScopeStack -> (Maybe Symbol, ScopeStack)
lookupSymbol :: Namespace -> Text -> ScopeStack -> Maybe Symbol
lookupInnermost :: Namespace -> Text -> ScopeStack -> Maybe Symbol
```

### Governance

- Lookup is innermost-first and stops at the first frame that binds the name in that namespace, which is exactly the shadowing rule in [[architecture/SEMANTICS]].
- `declareSymbol` returns the symbol it displaced *in the same frame* — a real conflict — separately from shadowing an outer frame, which is legal and is only ever a warning.
- The stack is a pure value: pushing and popping never mutate an existing frame, so a resolver can explore a scope and discard it without cleanup.
- A pop on an empty stack yields an empty stack rather than failing; the resolver's own structure guarantees balance, and a partial function here would turn a recovery path into a crash.
- No diagnostics, no policy about which conflicts are errors, and no knowledge of declaration syntax.

### Linkage

- **Requires:** [[Symbol Model]], [[grammar/haskell]].
- **Consumed by:** [[Name Resolution]].

## Algorithm

Keep a non-empty list of frames, each a `Map (Namespace, Text) Symbol`. Declaration inserts into the head frame and reports any same-frame predecessor; lookup folds outward through the frames.

## Negative Logic (Prohibited Paths)

- No global scope singleton, no name mangling, no ordering assumptions between namespaces, no partial indexing.

## Edge Cases

- Declaring the same name in the value and type namespaces of one frame is not a conflict; the two namespaces are independent.

## Depth

DEPTH 0.50 (MEDIUM). It hides frame representation and the shadow-versus-conflict distinction behind six total operations.

## Grill Log

- **Q:** Should the stack report shadowing? **A:** It reports same-frame displacement only; the resolver decides what shadowing means. _Rationale:_ shadowing legality depends on the displaced symbol's origin and on borrow state, which are policy, not storage. _Rejected:_ a Boolean "shadowed" flag; emitting diagnostics from the data structure.
- **Q:** Mutable environment or pure stack? **A:** Pure. _Rationale:_ a discarded scope must leave no trace, and pure frames make that structural rather than disciplined. _Rejected:_ a mutable map with an undo log.

## Referenced by

[[src/Pudu/Semantic/_MOC]] · [[Symbol Model]] · [[Name Resolution]] · [[Semantics]]
