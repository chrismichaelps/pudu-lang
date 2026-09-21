---
type: module
path: "@root/src/Pudu/Semantic/ScopeIndex.hs"
fidelity: Active
domain: "[[Compilation Artifact]]"
subsystem: "[[Semantic Analysis]]"
grammar: "[[grammar/haskell]]"
depth_score: 0.6
depth_status: MEDIUM
tags: [module, medium, semantic, tooling]
aliases: [Scope Index]
---

# Scope Index

## Purpose

Keep the lexical frames name resolution opened, after it has left them, so which bindings are
visible at a source position can be asked later — by completion — and answered exactly as
resolution would have.

## Interface

```haskell
data Frame = Frame { frameParent :: Maybe Int, frameExtent :: Maybe (Int, Int) }
data ScopeIndex
emptyScopeIndex :: ScopeIndex
scopeIndex      :: [(Int, Frame)] -> [(Int, Int, SymbolId)] -> ScopeIndex
visibleAt       :: ScopeIndex -> Int -> [SymbolId]
spanExtent, delimitedExtent :: Span -> Maybe (Int, Int)
spanningExtent  :: Span -> Span -> Maybe (Int, Int)
```

### Governance

- A frame's extent is the inclusive range of offsets a cursor may stand at inside it. A braced
  block's extent excludes the braces (`delimitedExtent`); an arm, closure, or declaration includes
  its end (`spanExtent`), because a cursor there is still writing its last expression. A frame with
  no extent is inside wherever its parent is.
- `visibleAt` finds the deepest frame that holds the cursor together with every ancestor, then walks
  up through the parents. Within a frame bindings are ordered latest-visible first; across frames,
  innermost first. Keeping the first binding of each name therefore reproduces shadowing.
- A binding is visible only strictly after its activation offset, so a `let` is not offered inside
  its own initializer.
- The index is an immutable product of one resolution run; nothing mutates it afterwards.

### Linkage

- **Requires:** [[Symbol]], [[Source]].
- **Consumed by:** [[Name Resolution]] (produces it), [[Lsp Completion]] (queries it).

## Negative Logic (Prohibited Paths)

- Do not decide visibility from declaration order alone; a sibling block's binding precedes the
  cursor and is still not visible.
- Do not interpret an offset from another file against this index.

## Grill Log

- **Q:** Why extents instead of recording the frames open at each reference? **A:** Completion asks
  about positions where nothing is referenced yet. _Rationale:_ an extent answers for any offset.
  _Rejected:_ recovering scope from the nearest reference, which says nothing about an empty line.

## Referenced by

[[src/Pudu/Semantic/_MOC]] · [[Name Resolution]] · [[Lsp Completion]]
