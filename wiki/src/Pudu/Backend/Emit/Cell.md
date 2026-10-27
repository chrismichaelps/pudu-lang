---
type: module
path: "@root/src/Pudu/Backend/Emit/Cell.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
aliases: [Backend Emit Cell]
---
# Backend Emit Cell

How one value sits in a cell: its C type and union member, retaining and
releasing it, rendering it inside an aggregate, member equality, ordering and
comparability, and the names of per-type helpers. Split out of [[Backend Emit
Aggregate]] (#556), which re-exports it, so [[Backend Emit Array]] can share it
without a cycle.

## Resolved Grill Log

- A move: the functions and their output are unchanged.

## Maps and sets (#561)

Both are owned boxes; mangled `MP_K_V_E` and `ST_T_E`.

## Range values (#564)

A range is an owned box, mangled `RG`.

## Bytes (#565)

Bytes are owned boxes, mangled `BY`.

## Referenced by

[[Backend Emit Aggregate]] · [[Backend Emit Array]]
