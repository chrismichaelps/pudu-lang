---
type: module
path: "@root/src/Pudu/Type/Check/Safety.hs"
fidelity: Active
domain: "[[Pudu Type]]"
subsystem: "[[Semantics]]"
depth_score: 0.45
depth_status: MEDIUM
coupling: 2.0
interface_stability: 0.8
tags: [module, medium, semantics]
aliases: [Type Check Safety]
---

# Type Check Safety

## Purpose and interface

Check named compile-time admission and report unused unsafe grants. Unsafe call requirements belong to function types in [[Type Value]] and are enforced by [[Type Check Rule]], including stored and aliased functions. Argument arity also belongs to the call rule.

Exports requireComptimePurity, checkComptimeCall, comptimeBuiltins, dottedName and reportUnusedCapabilities. Each operation reports through [[Type Env]]; this module neither evaluates a body nor grants a capability.

## Governance and algorithm

A compile-time declaration may be neither asynchronous nor unsafe; E3025 names its declaration. A direct callee known not to fold also receives E3025, except for the closed pure builtin list. Named admission recognizes a full dotted path only after localValueHead excludes a nearer local binding. An ordinary local function or receiver is not the module declaration whose spelling it shadows.

Function values do not carry compile-time admission metadata. Higher-order and local calls remain subject to the fold's runtime effect refusal. This rule does not claim transitive static purity. An unshadowed qualified ordinary function is still refused before folding.

reportUnusedCapabilities closes the current unsafe region. An empty grant with no observed use receives W3001; otherwise the warning names each granted capability that was unused. A function's own unsafe contract is checked separately, and its implied region does not earn this warning. Grant reporting changes no function type or call requirement.

dottedName joins a name/member chain and answers Nothing for an actual expression. Compile-time admission queries the full declaration spelling; ordinary fields and methods follow their receiver. Both nested and captured local name frames participate through [[Type Check Rule]].

## Negative logic

Do not infer types, walk expression bodies, evaluate callbacks, guess a module from capitalization or treat shared bare interface declarations as lexical shadows. Do not grant a shadowed callee its module's metadata or claim that function values preserve compile-time metadata.

## Resolved Grill Log

- **Q:** Inspect an imported function before a nearer local? **A:** No. Lexical identity determines whether named metadata applies.
- **Q:** Refuse every local or higher-order compile-time call? **A:** No. The fold already refuses effects when reached; a local is not a known non-foldable declaration.
- **Q:** Enforce unsafe calls or argument counts here? **A:** No. The ordinary call rule owns those typed contracts, preserving them through aliases.
- **Q:** Warn on an unsafe function whose body needs no grant? **A:** No. Its contract may express an invariant on its inputs; only explicit redundant regions are reported.

## Dependencies and consumers

Requires [[Type Env]], [[Type Check Rule]], [[Type Value]] and [[Syntax Tree]]. Consumed by [[Type Check]] and [[Type Check Expression]].

## Referenced by

[[src/Pudu/Type/_MOC]] · [[Type Check]] · [[Qualified Shadow Delivery]]
