---
type: module
path: "@root/test/Pudu/Frontend/ParserExpressionSpec.hs"
fidelity: Active
aliases: [Expression Parser Spec]
tags: [module, parser, test]
---
# Expression Parser Spec

## Purpose and algorithm

Coordinate named expression parser properties and re-export the precedence, primary, control
and recovery families for focused callers. Existing coverage includes literal/lambda/type arguments,
postfix/member/index/await, aggregate/record construction, control flow, recovery, reserved words,
hostile chains, budget latching and line-leading operators. Register `testFlatLists` from
[[Expression Recovery Spec]] in parserExpressionProperties and its import/re-export surface.
No production parser behavior or test framework dependency is introduced here.

## Resolved Grill Log

- **Q:** Leave the new width regression only in a manually invoked helper? **A:** No; aggregate
  registration and focused execution use the same property.

## Referenced by

[[src/Pudu/Frontend/Parser/_MOC]] · [[Expression Recovery Spec]] · [[Flat Expression List Delivery]]
