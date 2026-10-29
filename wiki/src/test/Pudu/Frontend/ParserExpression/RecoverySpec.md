---
type: module
path: "@root/test/Pudu/Frontend/ParserExpression/RecoverySpec.hs"
fidelity: Active
aliases: [Expression Recovery Spec]
tags: [module, parser, test]
---
# Expression Recovery Spec

## Purpose and interface

Expose recoveryProperties and focused expression tests for exact diagnostics, reserved keyword
guidance, hostile postfix/binary/conditional chains, ambiguous tails and latched exhaustion.
Genuine deep groups/arrays/Sets/calls must produce one E1099 without delimiter cascades.
Flat 520-argument calls and Sets are valid; previous E1099 expectations codified the width bug
and are deliberately corrected. No budget limit or diagnostic identity changes.

`testFlatLists` checks 2,048 distinct elements in arrays, Sets and calls, including trailing
commas, exact count/order and source/element spans. Moderate nesting after many siblings remains
valid. Malformed/missing elements and EOF retain focused baseline recovery diagnostics.
[[Expression Parser Spec]] registers this same family in the normal suite.

## Resolved Grill Log

- **Q:** Increase the 512-depth limit to pass flat lists? **A:** No; distinguish width from
  actual expression nesting, retaining every genuinely deep-source refusal.
- **Q:** Remove hostile tests that change meaning? **A:** No; explicitly accept the flat cases
  and preserve postfix, binary, conditional and deep delimiter checks.

## Referenced by

[[src/Pudu/Frontend/Parser/_MOC]] · [[Expression Parser Spec]] · [[Flat Expression List Delivery]]
