---
type: module
path: "test/Pudu/Type/Check/DeriveSpec.hs"
fidelity: Active
subsystem: "[[Semantics]]"
grammar: "[[grammar/haskell]]"
tags: [module, derive, tests]
aliases: [Type Check Derive Spec]
---

# Type Check Derive Spec

## Purpose and interface

Named properties prove generic definition checking independently of requests.
The type test coordinator registers them explicitly. Compiler helpers assert
exact diagnostic lists; loaded fixtures also assert expected runtime outputs.

## Algorithm and cases

Success cases cover valid definitions, canonical imported traits, generic trait
arguments, alpha-renamed member parameters and defaults. Refusals cover wrong
parameter/result contracts, stronger bounds, missing/extra/duplicate members,
non-trait heads, bad arity and duplicate shape definitions. Definition mistakes
report once even without a request. Loop sources must match their annotations;
nested loops retain outer bounds and discharge their own obligations while those
bounds exist. Later loop assumptions cannot prove a call made earlier.

The shared rigid-substitution property inspects preserved unsafe wrappers,
function default arity and higher-kind applications directly, so Type's relaxed
function-arity equality cannot hide lost metadata.

## Negative logic

Do not infer derive instantiation from a fixture that merely declares an unused
derive. Those fixtures prove definition checking only until generated impls exist.
Do not accept evaluator agreement without the expected output or ignore codes.

## Grill Log

- **Q:** Validate standard traits alone? **A:** Use small arbitrary user traits,
  generics and an imported interface. _Rationale:_ a hardcoded implementation
  cannot pass this contract matrix. _Rejected:_ only Eq or Json fixtures.
- **Q:** Test obligations only at method calls? **A:** Include a bounded generic
  function inside nested loops and before a later assumption. _Rationale:_ method
  lookup and delayed obligation discharge are distinct failure paths.

## Referenced by

[[src/Pudu/Type/_MOC]] · [[Type Test Coordinator]] · [[Type Check Derive]]
