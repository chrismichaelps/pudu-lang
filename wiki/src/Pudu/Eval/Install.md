---
type: module
path: "@root/src/Pudu/Eval/Install.hs"
fidelity: Active
domain: "[[Execution Result]]"
subsystem: "[[Runtime]]"
grammar: "[[grammar/haskell]]"
depth_score: 0.45
depth_status: MEDIUM
coupling: 3.0
interface_stability: 0.85
tags: [module, medium, runtime]
aliases: [Eval Install]
---

# Eval Install

## Purpose

Put a module's declarations into the environment before anything runs: functions, foreign
bindings, variant constructors, implementation methods, and then the constants that may reference
them.

## Interface

```haskell
type Evaluate = Located Expression -> Evaluator Value

loadDeclarations :: Evaluate -> [Located Declaration] -> Evaluator ()
targetNameOf     :: Located TypeSyntax -> Maybe Text
lastSegmentOf    :: NonEmpty Text -> Text
```

### Governance

- The wired-in sums record their variants' owners exactly as a declared sum does. Without it an implementation written for `Option` or `Result` is looked for under `Some` or `Err`, and is never found.
- **Order is the whole point.** Functions and variant constructors are installed before any constant
  runs, so mutual recursion and forward references work exactly as [[Name Resolution]] promised they
  would. A constant evaluated before its neighbours exist would make declaration order matter in a
  language whose resolution says it does not.
- An implementation's methods are installed under a key naming the type they implement for, and
  again under the trait, so a member access on a value and a trait-qualified call both find them.
- A trait member carrying a body is a default: an implementation that does not override it still
  has it, and `inheritedDefaults` is what puts it there.
- A variant is bound unqualified and under its type's name, so `Circle` and `Shape.Circle(3)` reach
  the same value.
- The `Evaluate` capability exists because a module constant's value is an expression, and
  evaluating one needs the environment this module is still building. One direction has to be an
  argument, and this is that direction.
- A foreign binding retains the block-local handle crossings, whether its result is owned, and
  whether it is the declared release for a handle. The evaluator therefore does not rediscover
  ownership from function names at call time.

### Linkage

- **Requires:** [[Eval Value]], [[Eval Env]], [[Syntax Tree]].
- **Consumed by:** [[Evaluator]].

## Algorithm

Install the built-in constructors, collect trait members into a table, install every declaration
against it, then evaluate each constant in declaration order.

## Negative Logic (Prohibited Paths)

- No evaluation of anything but a constant's initialiser, and that only through the capability.
- No installing a constant before the functions it may call.
- No typing decisions.

## Referenced by

[[src/Pudu/Eval/_MOC]] · [[Evaluator]] · [[Name Resolution]]
