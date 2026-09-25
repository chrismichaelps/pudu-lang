---
type: module
path: "@root/src/Pudu/Lsp/PatternCompletion.hs"
fidelity: Active
domain: "[[Compilation Artifact]]"
subsystem: "[[Tooling]]"
grammar: "[[grammar/haskell]]"
depth_score: 0.7
depth_status: MEDIUM
tags: [module, medium, tooling, lsp]
aliases: [Lsp Pattern Completion]
---

# LSP Pattern Completion

## Purpose

Turn a checked match subject, its syntax context, and canonical visible-sum facts into legal pattern
candidate labels and payload details. Protocol JSON and general completion remain outside this module.

## Interface

```haskell
data PatternCandidate = PatternCandidate
  { candidateLabel  :: Text
  , candidateDetail :: Text
  }

patternCandidates
  :: Maybe TypeInfo
  -> Map Text SumShape
  -> Module
  -> Located Expression
  -> [Located MatchArm]
  -> Located MatchArm
  -> Int                -- the cursor
  -> [PatternCandidate]
```

### Governance

- The cursor's position in the arm's pattern decides the type whose variants are offered. At the
  top of the pattern it is the subject's type, and earlier unguarded arms cover variants. Inside a
  constructor's payload it is that payload's declared type, followed from the subject through each
  enclosing constructor with the subject's arguments substituted — a same-module sum, `Option`, or
  `Result`; coverage does not apply there, because arms cover whole values. Inside a tuple, a
  sequence, a record, or a payload whose type is not a known sum, only `_` is offered.

- The checked subject's canonical nominal identity selects exactly one sum. Same-spelling types and
  variants do not cross that boundary.
- Candidate spelling follows the root module: local unambiguous variants are bare, local collisions
  use `Type.Variant`, selective imports use the imported variant or type spelling, and module imports
  use their qualifier or alias.
- Payload detail preserves unit, positional, and named shapes. Declared type parameters are replaced
  with the checked subject's concrete arguments for display.
- Coverage is conservative and source-ordered. Earlier unguarded wildcard/binding patterns cover every variant. Constructor or
  named-record payloads cover a variant only when their nested patterns are irrefutable; alternatives
  cover a variant when one branch does. Guards and refutable payloads never suppress a candidate.

## Negative Logic (Prohibited Paths)

- Do not search every constructor by spelling or infer an owner from a variant name.
- Do not suppress a variant merely because an arm mentions it.
- Do not render unresolved inference variables as a promise about a payload; use the checked type's
  ordinary renderer and retain syntax when no substitution exists.
- Do not construct LSP JSON here.

## Grill Log

- **Q:** Why separate candidate policy from `Completion`? **A:** Coverage, import spelling, collision
  handling, and generic payload rendering form one independently testable language-tooling policy.
  _Rationale:_ the dispatcher remains below the source-size boundary and does not mix protocol items
  with pattern semantics. _Rejected:_ adding another hundred lines to the general completion module.
- **Q:** Why not reuse exhaustiveness diagnostics directly? **A:** Exhaustiveness reports whether a
  whole match covers its domain, while completion asks whether one candidate would still be useful at
  one arm and must preserve editor spelling. _Rationale:_ both follow the same conservative laws, but
  their products and presentation differ. _Rejected:_ parsing diagnostic prose or suppressing every
  constructor mentioned by any arm.

## Referenced by

[[src/Pudu/Lsp/_MOC]] · [[Lsp Context]] · [[Lsp Shapes]] · [[Lsp Completion]]
