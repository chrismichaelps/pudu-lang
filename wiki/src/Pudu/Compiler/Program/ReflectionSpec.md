---
type: module
path: "test/Pudu/Compiler/Program/ReflectionSpec.hs"
fidelity: Active
subsystem: "[[Semantics]]"
grammar: "[[grammar/haskell]]"
tags: [module, derive, tests]
aliases: [Program Reflection Spec]
---

# Program Reflection Spec

## Purpose and interface

`reflectionProgramProperties` compiles complete temporary programs against the
distributed Std.Meta facade and checks exact diagnostics and descriptor types.

## Algorithm and evidence

Use arbitrary user traits with unused derive definitions, so checks occur once
at definitions. Cover qualified, aliased and selected imports; property reads;
owner-specific get/set/matches; nested variant fields; abstract field variables;
wrong owners, wrong held types, concrete heterogeneous annotations and sequence
misuse. Runtime references remain refused even when a Meta function is captured.
Each case runs through graph discovery, imported signatures and ordinary checking.
An additional ordinary generic Box trait matrix proves the same receiver rule
for direct calls, borrowed receivers, captured methods, result types and distinct
instantiations. Integer literals and rigid-bound self arguments receive explicit
negative cases; rejecting Bool alone does not protect deferred integer inference.

## Negative logic

No isolated mocks, swallowed diagnostics or claims that declaring an unused derive
proves residualization. Fixture generation is confined to temporary directories.

## Grill Log

- **Q:** Why loaded programs? **A:** Accessor ownership and alias identity rely on
  canonical imported schemes, which isolated parsing cannot prove.
- **Q:** Why arbitrary traits? **A:** Reflection typing must serve every derive,
  independently of the library's eventual Eq/JSON declarations.

## Linkage and references

Requires [[Pudu Program]], [[Std Meta]], [[Type Check Reflection]].
Consumed by [[Program Spec]]. Referenced by [[src/Pudu/Compiler/_MOC]].
