---
type: module
path: "@root/src/Pudu/Backend/Runtime/Dependencies.hs"
fidelity: Active
aliases: [Native Runtime Dependencies]
grammar: "[[grammar/haskell]]"
---
# Native Runtime Dependencies

## Purpose and interface

Export runtimeDependencies :: Text -> [Text]. Compose existing
integerRuntimeDependencies with [[Native Floating Runtime]] dependencies.
Both legacy runtimeNeeds and actual frame assembly traverse this same facade.
Keep the old integer API intact for integer-only callers and tests. The facade
owns no ordering, closure state, IO or RuntimePart type; catalogues supply ordered
parts and callers perform their existing cycle-safe visited-set closure.

## Resolved Grill Log

- **Q:** Hide floating dependencies in the integer catalogue? **A:** Use a general facade and retain the existing integer contract.
- **Q:** Import Runtime to compute prerequisites? **A:** No; avoid a catalogue/type cycle.

## Dependencies and consumers

[[Backend Runtime Integer]] · [[Native Floating Runtime]] · [[Backend Emit Support]] · [[Backend Frame Program]] · [[Native Floating Runtime Tests]]

## Arrays (#556)

Resolved Grill Log: includes the array parts' prerequisites.

## Referenced by

[[src/_MOC]] · [[Backend Module Map]] · [[Native Floating Runtime Delivery]]

## Text prerequisites (#515)

The facade also delegates to [[Native Text Runtime]]'s dependency table.

## Text method prerequisites (#516)

The facade also delegates to [[Native Text Methods]].

## Case prerequisites (#517)

The facade also delegates to [[Native Text Case]].

## Char prerequisites (#518)

The facade also delegates to [[Native Char Runtime]].

## Aggregate prerequisites (#521)

The facade also delegates to [[Native Aggregate Runtime]].
