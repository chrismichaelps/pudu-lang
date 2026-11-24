---
type: module
path: "@root/src/Pudu/Compiler/Lower/Keyed.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
aliases: [Compiler Lower Keyed]
---
# Compiler Lower Keyed

## Purpose and interface

`lowerMapOf`, `lowerSetOf`, `lowerSetLiteral`, `lowerKeyedMethod` and
`setMembership`: maps and sets under [[Native Maps and Sets]].

## Order and failures

The receiver runs before the supplied arguments. `get` puts the
key in a local and builds `Some` or `None` in Core from a containment test and
a lookup, so no C code needs an Option's layout. Where the key type could hold
a function, every key is tested before it is stored, and one that cannot be
ordered fails with E7008 naming its kind as `valueKind` does (a sum by the
variant it holds): after all the members of a literal or `setOf`/`mapOf`
array, at the call for `insert`. Where it couldn't, no test is emitted.

## Resolved Grill Log

- **Q:** Why test in Core rather than in C? **A:** The message needs the
  variant name of a sum key, and Core already has `CoreRuntimeKind` and
  `CoreFailText`.
- **Q:** Does `for` over a map snapshot it? **A:** Yes, `entries()` first, as
  `walkValues` lists the entries before the body runs.

## Dependencies and consumers

[[Compiler Lower Array]] · [[Compiler Lower State]] · [[Compiler Lower Types]] · [[Core IR]]

## Referenced by

[[Compiler Lower Body]] · [[Compiler Lower For]] · [[Native Maps and Sets]] · [[src/Pudu/Compiler/_MOC]]

## First-class output builtins (#569)

Resolved Grill Log: Use CoreRuntimeKind for callable key E7008 as well as sum variants, retaining existing comparability guards and evaluation order.

## Shared builder (#631)

Export keyedFromArray: given the tag, solved result and lowered array it
builds what mapOf/setOf build, or Nothing for a mismatched type. A flag
picks whether key refusals use the call span or the caller site.
Resolved Grill Log: the direct call and the value body share it, so key
checks, E7008 wording and duplicate handling cannot drift.

## Indexed stores (#840)

lowerKeyedMethod answers the seven store methods with the map's operations at key Int. A store's key operand is wrapped in `&+ 0`, folding a deferred magnitude into the word the interpreter narrows to. Export Blame, orderable and mayHoldFunction for [[Compiler Lower Multi Map]]. Resolved Grill Log: narrowing in lowering keeps one key convention in the helpers.

## Set membership (#948)

`setMembership` answers `candidate in set` with the set's `contains`
primitive. The candidate is declared first and the set second, so the
operands run in source order as the interpreter evaluates them; the
membership probe reads both locals. The checker types `in` as
`T in Set[T]`, so no other right operand reaches it.

Resolved Grill Log: reuse `KeyedContains` instead of a new Core operator;
the probe applies no orderability check, matching `Set.contains` and the
interpreter's `setContains`.

## Dynamic keys and values (#956)

Resolved Grill Log: set literals and keyed methods widen their supplied
values to their checked carriers before membership, ordering, or storage.
Only the carrier changes. Operand order, rejected-key spans and collection
ownership stay with the existing operations.

## Runtime keyed layouts (#956)

Resolved Grill Log: Construction reads the lowered item layouts. Updates and binary operations rebuild wider carriers from the retained entries. Lookups return an Option whose payload carrier matches the stored value.

Resolved Grill Log. A set literal uses the array literal's carrier
join for its items. A map builder joins the actual pair fields so
key and value storage retain their separate layouts.

## Held collection member selection

Resolved Grill Log: Keyed calls consume a retained receiver, so a missing member stops before keys or values evaluate.

## Held keyed method arguments

Resolved Grill Log: a store validates and folds an integer key,
whereas maps and sets accept arbitrary held keys and values. Merge
and set algebra check the argument family after evaluation and then
settle a shared collection layout.

Resolved Grill Log: a store folds every key into one signed word before lookup, insertion and removal, an Int already beyond that word included, so its keys always read back within Int as evaluation keeps them.
