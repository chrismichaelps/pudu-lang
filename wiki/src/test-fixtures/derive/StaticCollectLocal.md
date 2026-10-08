---
type: module
path: "@root/test-fixtures/derive/StaticCollectLocal.pudu"
fidelity: Active
tags: [fixture, derive, expansion]
aliases: [Static Collect Local Fixture]
---
# Static Collect Local Fixture

## Purpose and interface

Define and request a local aggregate strategy whose collect discards a generic optional result.
The selected element capability still runs. The entry returns an empty diagnostic string.

## Algorithm and resolved Grill Log

Run the derive, print its expansion, remove the local strategy and request, and compile that
ordinary expanded Pudu source. Both evaluators must return the same value without diagnostics.
This verifies generic owner selection survives printing without broadening index syntax.

## Referenced by

[[Derive Library Spec]] · [[src/_MOC]] · [[2026-10-07-static-field-selection]]

The derived call also initializes a constant, so folding must preserve the same owner selection.
