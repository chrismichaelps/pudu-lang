---
type: grammar
language: Haskell
version: "GHC 9.14.1"
tags: [grammar]
aliases: [Grammar — Haskell]
---

# Grammar — Haskell

## Toolchain Lock

- GHC 9.14.1, the stable release tagged `latest` by GHCup when the vault was established on 2026-08-21.
- Cabal-install 3.16.1.0 with `cabal-version: 3.12` project files.
- Haskell Language Server 2.14.0.0 where an editor build supports the locked compiler.
- GHCup manages developer installations; Cabal is the sole project build interface. Stack metadata is not maintained.
- CI and release builds select exact versions; local builds must not silently select an older compiler.
- Cabal dependency resolution is pinned to Hackage index state `2026-08-15T18:36:33Z` until intentionally refreshed and reviewed.

Official anchors: [GHCup](https://www.haskell.org/ghcup/) · [GHC](https://www.haskell.org/ghc/) · [Cabal](https://www.haskell.org/cabal/) · [HLS](https://github.com/haskell/haskell-language-server/releases)

## Language Baseline

- `default-language: GHC2024`.
- Enable extensions per component or module only when they remove boilerplate without obscuring inference.
- Approved initial extensions: `DeriveAnyClass`, `DeriveFunctor`, `DeriveGeneric`, `DerivingStrategies`, `GeneralizedNewtypeDeriving`, `LambdaCase`, `NamedFieldPuns`, `OverloadedStrings`, `RecordWildCards`, `StrictData`.
- `StrictData` is the default for compiler-domain records; intentionally lazy fields require an invariant comment.

## Imports and Namespaces

- Every module has an explicit export list.
- Import identifiers explicitly except for the small Prelude surface.
- Use qualified imports for `Data.Map.Strict` as `Map`, `Data.Set` as `Set`, and `Data.Text` as `Text` when both type and functions are used.
- Prefer `Data.Text` for decoded source and user messages; use `String` only at host APIs that require it.
- Prefer strict `Map` and `State` representations in compiler phases.
- No umbrella project module that re-exports implementation internals.

## Core Result Patterns

- Expected user failures return domain values; they do not throw exceptions.
- A phase returning diagnostics uses a dedicated result type that preserves all recoverable diagnostics and never relies on `error`.
- Host IO exceptions are caught at the CLI or toolchain boundary and translated into typed compiler failures.
- Internal invariants may use total constructors that make invalid states unrepresentable; partial selectors are prohibited.

## Data Modeling

- Use `newtype` for source identifiers, offsets, diagnostic codes, symbol IDs, and other nominal scalar identities.
- Use closed algebraic data types for tokens, syntax, types, and IR instructions.
- Keep phase-owned types in their phase module; cross-phase types require an explicit domain module page.
- Store source spans on syntax nodes or wrappers uniformly; do not add ad hoc position fields to selected constructors.
- Use smart constructors when raw construction could violate ordering, range, or ownership invariants.

## Naming and Layout

- Modules: `Pudu.<Subsystem>.<Responsibility>`.
- Types and constructors: `PascalCase`; functions and values: `camelCase`.
- Predicates use `is`, `has`, or `can`; conversions use `to`, `from`, `render`, or `parse` according to direction.
- Files target fewer than 500 lines and one architectural responsibility.
- Formatter: `ormolu` once a GHC-9.14-compatible release is selected; until then source follows four-space continuation indentation and `cabal-fmt`-stable project files.

## Performance Laws

- `cabal.project` disables optimization for fast development/test cycles. CI/release commands pass `--enable-optimization=2`; package files do not hard-code `-O0`, which keeps `cabal check` distribution-clean.
- Use strict accumulators in source traversal, symbol tables, and diagnostics collection.
- Avoid repeated `Text` concatenation in loops; use builders or accumulated chunks.
- Do not optimize without a benchmark or allocation profile demonstrating the bottleneck.
- Phase APIs stay pure where possible so performance and property tests remain deterministic.

## Diagnostic Laws

- Stable diagnostic codes are declared centrally and rendered separately.
- Every user-originated failure carries a source span when one exists.
- Rendering never decides semantic severity or recovery behavior.
- Tests compare structured diagnostics first and rendered snapshots second.

## Comments

- Required on module headers and domain/phase boundary types using Haskell Haddock block syntax, for example `{-| @Source.Text.Module — preserves stable source locations -}`.
- Explain invariants, phase boundaries, compatibility constraints, or non-obvious performance choices.
- Do not narrate methods, locals, or self-describing transformations.

## Prohibited Patterns

- No `undefined`, `error`, `head`, `tail`, partial `read`, partial map indexing, or incomplete pattern matches in production modules.
- No global mutable compiler state or `unsafePerformIO`.
- No exceptions for lexical, syntactic, type, ownership, or Pudu runtime failures.
- No orphan instances.
- No wildcard exports.
- No backend imports from frontend or semantic modules.
- No unbounded recursion over attacker-controlled source when an iterative or tail-recursive form is practical.

## SDK Discovery Map

- Base/compiler APIs: local GHC 9.14.1 Haddocks and [Hoogle](https://hoogle.haskell.org/).
- Package APIs: installed package Haddocks and canonical Hackage documentation.
- Before introducing a package or unfamiliar function, confirm its exact type and locked version; record new stable patterns here.

## Senior Definition Needed

- Exact formatter version remains pending verified GHC 9.14 support; formatting is enforced structurally until resolved.
- Direct LLVM API patterns are intentionally absent because [[ADR-0002-compiler-pipeline]] selects C11 emission for v1.

## Referenced by

[[grammar/_MOC]] · [[FMCF Workflow]] · [[architecture/OVERVIEW]] · [[src/_MOC]]
