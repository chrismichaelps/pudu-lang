---
type: module
path: "@root/lib/Std/MdSpan/Layout.pudu"
fidelity: Active
grammar: "[[grammar/pudu]]"
aliases: [Std MdSpan Layout]
---
# Std MdSpan Layout

## Purpose and interface

Pure checked metadata for dynamic multidimensional views. Export Mapping and
of(extents, strides) -> Option[Mapping]. Mapping carries extents, strides,
size, requiredSpanSize, unique and exhaustive. No array storage or IO.

## Invariants and resolved Grill Log

Reject negative/mismatched extents and strides and nonrepresentable size or
footprint before arithmetic. An empty index space has zero size/footprint;
rank zero has one position. Sort active dimensions by stride using rank-sized
storage. Starting from a one-position interval, disjoint slabs prove
uniqueness; strides no larger than current coverage prove exhaustiveness.
Zero-stride repeated dimensions are nonunique but may still be exhaustive.
False uniqueness may be inconclusive; true is a proof. Never enumerate the
logical elements merely to inspect their layout.

## Dependencies and consumers

[[Std MdSpan]] · [[C++ Inspired View Coverage]]

## Referenced by

[[src/Std/_MOC]] · [[Std Views Delivery]]
