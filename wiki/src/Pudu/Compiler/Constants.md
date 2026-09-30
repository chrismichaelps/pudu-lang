---
type: module
path: "@root/packages/pudu/v0.1/src/Pudu/Compiler/Constants.hs"
fidelity: Active
subsystem: "[[Tooling]]"
grammar: "[[grammar/haskell]]"
tags: [module]
aliases: [Compiler Constants]
---

# Compiler Constants

## Purpose

Select dependency products for one module's compile-time evaluator without including unrelated
modules or untyped syntax.

## Interface

`foldingInputs` takes parsed graph modules, dependency order, consumer identity and checked products.
It returns frozen constants by canonical module name, merged literal-kind facts, and checked module
syntax in link order.

## Algorithm

Walk the consumer's transitive imports with a visited set. Exclude the consumer itself. Select only
available checked products with executable module syntax in the graph's stable dependency order.
Collect their frozen constants and integer kinds without forcing unused fold inputs.

## Invariants and failure cases

The graph owns ordering; this selector never repeats discovery or constructs interfaces. Signature
cycles cannot cause recursion and unavailable cyclic value initializers remain evaluator diagnostics.
Modules rejected during compilation provide no executable inputs.

## Grill Log

- **Q:** Link every earlier compiled module? **A:** No; only transitive imports belong in the fold,
  otherwise unrelated modules consume budgets and introduce declarations outside the dependency graph.
- **Q:** Use parsed dependencies before they check? **A:** No; executable products must be checked,
  with the same folded constants and literal kinds that runtime execution consumes.

## Linkage

Requires [[Compiler Pipeline]] and [[Syntax Tree]]. Consumed by [[Compiler Program]].

## Referenced by

[[Compiler Program]]
