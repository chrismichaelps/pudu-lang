---
type: module
path: "@root/src/Pudu/Compiler/Lower/Markup.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
aliases: [Compiler Lower Markup]
---
# Compiler Lower Markup

## Purpose

`keepMarkup` wraps a lowered call into the markup modules in a kept module constant, so page markup built from literals alone is built once per run instead of at every evaluation.

## Contract

A call is kept only when all of these hold:

- its callee is a function of `Std.Html`, or of its `Build` submodule (`Std.Html.Build.*`); other submodules are excluded;
- its result type is `Std.Html.Html` or `Std.Html.Build.Node`;
- it is closed: its operands are literals (integer, float, decimal, bool, text, char), kept constants, arrays, tuples, records, constructions, and closed markup calls, through a block with no statements and a result. Naming any local makes the call open;
- its size is at least four expressions.

A kept call is keyed by its call site and its result type, so each site has its own constant. Call sites that route through this module are the named, module-qualified and method calls in [[Compiler Lower Body]].

## Resolved Grill Log

Why only the markup modules: their functions build values and reach nothing outside the program. A user function may read state or perform effects, and keeping its first result would change what a later call returns.

Why a closed call only: a call whose operand is a local changes with each evaluation, so keeping its value would be wrong. Such a call is left exactly as it was lowered.

Why a size floor of four: a call of three expressions or fewer is cheap to build, and keeping it would only add a constant. Calls at the floor and above are the page-level blocks the constant is for.

## Referenced by

[[Compiler Lower Body]] · [[Native HTML Kernel]]
