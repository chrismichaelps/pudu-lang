---
type: module
path: "@root/src/Pudu/Lsp/Receiver.hs"
fidelity: Active
domain: "[[Compilation Artifact]]"
subsystem: "[[Tooling]]"
grammar: "[[grammar/haskell]]"
depth_score: 0.55
depth_status: MEDIUM
tags: [module, medium, tooling, lsp]
aliases: [Lsp Receiver]
---

# LSP Receiver

## Purpose

Find the member access a completion is for — where its dot is and the whole receiver expression
before it — and the type the checker gave that receiver.

## Interface

```haskell
data MemberSite = MemberSite { siteDot :: Int, siteReceiver :: (Int, Int) }
memberSiteAt :: [Token] -> Int -> Maybe MemberSite
receiverType :: TypeInfo -> MemberSite -> Maybe Type
```

### Governance

- The site is read from the lexer's tokens, which exist whether or not the text parses, so
  `text.` in an unclosed function is found as surely as `text.length()`.
- The cursor is right after a dot, or inside or at the end of the name written after one. Trivia —
  whitespace and comments — between the receiver and the dot changes nothing, because tokens carry
  trivia separately. A range operator is its own token and never a dot.
- The receiver is the whole postfix expression ending before the dot, walked backwards: an operand
  token (name or literal), a balanced group preceded by a callee (a call or an index), a bare group,
  a `?`, and further `.`-separated operands to the left. `produce(1)` is the call, never its last
  argument; `items[0]` the element; `a.b.c` the chain.
- The receiver's type is the expression recorded at exactly its offsets (`typeAtOffsets`), or
  failing that the widest recorded expression inside them (`widestWithin`), which is what a group
  or recovered span reduces to. Hover's point query is not used: its innermost answer is the right
  one for hover and the wrong one for a receiver.

### Linkage

- **Requires:** [[Token]], [[Source]], [[Type Boundary]].
- **Consumed by:** [[Lsp Completion]], [[Lsp Import Completion]].

## Negative Logic (Prohibited Paths)

- Do not decide a member position from the scalar before the dot.
- Do not ask for the type at the offset before the dot; a call's last argument ends there.

## Grill Log

- **Q:** Why tokens rather than the tree's `MemberExpression`? **A:** Completion is asked while the
  member is unwritten, and `text.` alone does not parse. _Rationale:_ one reading that works for both
  written and unfinished text. _Rejected:_ a tree query that answers only once the program parses.

## Referenced by

[[src/Pudu/Lsp/_MOC]] · [[Lsp Completion]] · [[Lsp Import Completion]]
