---
type: module
path: "@root/lib/Std/Env.pudu"
fidelity: Active
aliases: [Std Env]
tags: [module, stdlib, environment]
---
# Std Env

## Purpose and interface

Expose process arguments, environment lookup, portable locations, executable identity, termination
and a monotonic clock. Argument helpers are `all`, `count`, `at`, `hasFlag`, `option` and
`positional`; environment helpers are `variables`, `variable`, `variableOr`, `isSet` and
`searchPath`. Locations are `homeDirectory`, `temporaryDirectory` and `executable`. Termination
helpers are `stop`, `succeed` and `fail`; `elapsedMilliseconds` wraps the monotonic runtime clock.

## Semantics

Arguments retain shell order and spelling. `option` accepts separate and equals forms, with the
first occurrence winning; a final unvalued option is absent. Positional filtering skips values only
for the flags the caller declares. Empty environment values remain present. Search paths retain
order and use the native separator. Home/temp/executable locations come from runtime primitives;
the executable result preserves recoverable errors. `fail` attempts standard-error output then
exits one. Clock readings express elapsed durations, not wall time.

## Grill Log

- **Q:** Can the desktop loop hardcode a temporary path or treat elapsed time as a timestamp?
  **A:** No. Portable runtime locations and monotonic durations preserve those distinct contracts.
- **Q:** Does this mirror change the runtime interface? **A:** No. It documents the existing source
  and resolves the desktop App dependency backlink without changing implementation.

## Dependencies and consumers

Uses runtime/prelude argument, environment, path, output, process and clock primitives. Consumed by
[[Std Desktop App]], desktop tooling and ordinary applications.

## Referenced by

[[src/Std/_MOC]] · [[Std Desktop App]]
