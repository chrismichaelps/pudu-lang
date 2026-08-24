---
type: module
path: "@root/src/Pudu/Repl/Describe.hs"
fidelity: Active
domain: "[[Pudu Program]]"
subsystem: "[[Tooling]]"
grammar: "[[grammar/haskell]]"
depth_score: 0.4
depth_status: SHALLOW
coupling: 2.0
interface_stability: 0.8
tags: [module, shallow]
aliases: [Repl Describe]
---

# Repl Describe

## Purpose

Answer what the session knows about a name: how it was declared (`:info`), how many type
arguments it takes (`:kind`), which traits are implemented for it (`:instances`), and what the
session contains at all (`:show declarations`, `:show imports`).

## Interface

### Signatures

```haskell
describeName :: Module -> Text -> [Text]
describeKind :: Module -> Text -> Maybe Text
describeKindLines :: Module -> Text -> [Text]
describeInstances :: Module -> Text -> [Text]
declarationSummary :: Module -> [Text]
importSummary :: Module -> [Text]
```

### Governance

- Every answer is rendered from the session's own parsed module. The prompt therefore reports what
  the session would compile, not what a parallel bookkeeping record remembers, so the two cannot
  drift apart.
- `describeKind` reports **arity**, not a kind in the type-theoretic sense: Pudu has no kind system, and
  claiming one would describe a language that does not exist. `type -> type` says the constructor
  still expects an argument, which is the question a reader is actually asking.
- Wired-in constructors answer from the same arity table the checker uses, because a reader cannot
  tell a compiler-provided type from a declared one and should not have to.
- The session's synthetic wrapper function is filtered out of `declarationSummary`: it is an
  artifact of how entries are compiled, not something the reader declared.

### Linkage

- **Requires:** [[Syntax Tree]], [[Syntax Name]].
- **Consumed by:** [[Pudu REPL]], [[Repl Session]].

## Algorithm

Linear scans of `moduleDeclarations` filtered by name, rendering each matching declaration back
into its written form. `:instances` scans implementations for a matching target head.

## Negative Logic (Prohibited Paths)

- No type checking, no inference, and no evaluation: a description never runs the code it describes.
- No invented kind signatures for a language without kinds.
- No fabricated arity for a name the session has never seen; unknown names are reported as unknown.

## Edge Cases

- A name declared more than once describes the first declaration, matching the shadowing the
  session already applies.
- A type with no implementations reports that plainly rather than printing an empty answer.

## Depth

DEPTH 0.40 (SHALLOW by intent). It is a projection of the parsed module for the inspection commands.

## Grill Log

- **Q:** Should `:kind` print `*` and `* -> *`? **A:** No. _Rationale:_ borrowing a
  notation implies borrowing the kind system behind it, which Pudu does not have; `type -> type`
  says the same thing without the false promise. _Rejected:_ star notation; inventing a kind
  language purely for the prompt.
- **Q:** Should descriptions come from the checker's environment rather than the syntax tree?
  **A:** Not yet. _Rationale:_ the syntax tree is what the reader wrote, and `:info` is asked
  "what did I declare?" rather than "what did you infer?". Type-level answers belong to `:type`.
  _Rejected:_ rendering from `Resolution` alone, which loses the written form.

## Referenced by

[[src/Pudu/Repl/_MOC]] · [[Pudu REPL]] · [[Repl Command]]
