---
type: module
path: "@root/packages/pudu/v0.1/src/Pudu/Foreign/Call/Run.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
aliases: [Foreign Run Storage]
---

# Foreign Run Storage

Query a scalar or nested record's ABI stride and leaf offsets. Own a
non-null aligned buffer during the call. Convert each element through the
existing integer, float and record carriers.

## Resolved Grill Log

- Query stride from libffi, including record tail padding. Reuse the
  interpreter's fixed-width leaf codecs.
- Check count times stride before allocating or reading. Allocate one byte
  for a present, zero-length run.
- Hold storage across the call in a bracket. A mutable run reads its
  elements before storage goes away. An owned returned run can use the same
  decoder without taking over its producer's destructor contract.

## Resolved Grill Log for #877 — Interpreter array crossings

Prepare layouts and check declared bounds before symbol dispatch. Calls without runs or bounds use the empty preparation value. Across raw calls, keep each input run alive with a bracket and merge its mutable snapshot into the original native argument order.

## Resolved Grill Log for #877 — Nullable loans

An absent typed run has zero capacity in either unit and does not allocate storage. A present empty run uses the ordinary non-null scratch allocation.

## Referenced by

[[Foreign Call]] · [[Foreign Pointers and Runs]] · [[src/Pudu/Foreign/_MOC]]
