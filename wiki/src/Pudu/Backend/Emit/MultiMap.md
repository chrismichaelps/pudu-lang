---
type: module
path: "@root/src/Pudu/Backend/Emit/MultiMap.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
aliases: [Backend Emit Multi Map]
---
# Backend Emit Multi Map

## Purpose and interface

The generated add helper for a MultiMap record. The helper updates the record
and both maps in place when they are held once, and otherwise builds a new
record.

## Contract

- One helper per MultiMap instantiation, keyed on the record type
  `{ groups: Map[K, Array[V]], occurrences: Map[(K, V), Int] }`.
- The record is exclusive when its count is one. A map is exclusive when the
  record is exclusive and the map box's count is one. A map box held once inside
  a shared record stays reachable from the record's other holders, so it is
  not exclusive.
- With an exclusive groups map, the key's array is taken out of its tree node
  when every node on the search path is held once. Otherwise the array is
  retained.
- An exclusive map inserts into its own tree, so the tree runtime reuses each
  exclusive node. A shared map inserts into a retained copy of its tree.
- An exclusive record keeps its box and receives the new maps. A shared record
  gives a new record.
- The occurrence count cannot overflow. It never exceeds the number of values
  the map holds, and memory bounds that number below the Int limit.

## Resolved Grill Log

Resolved Grill Log: values the program holds alone reach the tree and array in-place
paths through [[NATIVE-OWNERSHIP]]; this helper is the MultiMap consumer of that ownership.

## Dependencies and consumers

[[Backend Emit Keyed]] · [[Native Persistent Trees]] · [[Backend Runtime Array]]

## Referenced by

[[NATIVE-OWNERSHIP]] · [[Native Aggregate Emission]] · [[Compiler Lower Multi Map]]
