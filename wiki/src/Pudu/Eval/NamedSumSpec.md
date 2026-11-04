---
type: module
path: "@root/test/Pudu/Eval/NamedSumSpec.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
tags: [module, test, runtime, nominal]
aliases: [Named Sum Value Properties]
---
# Named Sum Value Properties

## Purpose and interface

namedSumProperties :: [(String, IO Property)] supplies focused runtime representation
laws to [[Eval Test Coordinator]], registered in [[Pudu Test Cabal Manifest]].

## Algorithm and invariants

Construct explicit owned named values in host fixtures before source publication.
Check owner/tag inequality and distinct ordinary-record/positional shapes under
Eq, compareValues and keyed sets. Keep display labels and nested payload
semantics; integer literal field patterns ignore integer storage width. Round-trip frozen nested named values and
reject every strict stored prefix and fields containing nonportable builtins.
Test canonical/anonymous/raw patterns, owner/tag mismatch, missing and partial
fields, ordinary-record and positional refusal. Read and replace a nested field
through the ordinary evaluator/place path without losing owner/tag. Exercise
receiverOwners against a contradictory short-tag registry and iterate one named
payload through the real evaluator with an injected runtime binding.

## Negative logic

No new source construction path, private constructor layout assertions or timing
thresholds. Do not claim source dispatch is fixed before checked publication.

## Resolved Grill Log

A distinct value prevents nested-module record keys from colliding with sum
owner-plus-tag text. Direct runtime laws make the representation partition
reviewable before the checker publishes named values. Use existing evaluator
and persistence harnesses; structured failures retain source provenance.

## Referenced by

[[src/Pudu/Eval/_MOC]] · [[Named Sum Value Delivery]] · [[Eval Value]]
