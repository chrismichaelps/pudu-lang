---
type: module
path: "@root/src/Pudu/Compiler/Lower/Layout.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
aliases: [Compiler Lower Layout]
---
# Compiler Lower Layout

## Purpose and interface

Export `moduleLayouts`: the layout of every record and sum a lowered module
mentions, closed over the layouts they reach, for `coreModuleLayouts`.

## Grill Log

- **Q:** Why carry layouts beside the functions instead of inside the types?
  **A:** Types name records and sums by identity only, so a recursive sum stays
  a finite type; the layout map is where each is spelled out once.

## Closure layouts (#555)

Resolved Grill Log: every function type met gets a `CoreClosureLayout` of the
lifted functions whose closure has that type, empty when none was made.

## Arrays (#556)

Resolved Grill Log: an array type's element and the new Core shapes are
collected.

## Sequence patterns (#558)

A sequence pattern contributes its items' locals and its bound rest's.
`CoreFailText`'s computed help is walked like its message.

## Integer conversion (#560)

The conversion shapes contribute their operand's locals.

## Maps and sets (#561)

A map contributes its key, its value and the `(key, value)` tuple its entries
use; a set its member.

## Char from a code (#562)

`CoreCharOfCode` contributes its operand's locals.

## Range values (#564)

Range shapes contribute their operands' locals.

## Bytes (#565)

Byte operations contribute their operands' locals.

## Referenced by

[[Compiler Lower]] · [[Core IR]] · [[src/_MOC]]

## Output Results (#566)

Resolved Grill Log: CoreOutputError contributes its operand types and locals during layout collection, including the surrounding Result layout. See [[Native Output Results]].

## Named callable dispatch (#568)

Resolved Grill Log: Form named callable layout keys from all actual parameters and result; lifted lambda keys still use their first environment parameter. Handle zero-parameter named functions.
