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

## Resolved Grill Log for #876 — Native callback lowering

The callback token occupies a uintptr_t frame cell. The run retains its
handler and owns registration lifetime.

## Referenced by

[[Backend Emit Aggregate]] · [[Backend Emit Array]]

## BigInt (#800)

A BigInt is an owned cell: C type `pudu_big *`, member `big`, retained and released by `pudu_big_retain` and `pudu_big_release`, rendered by `pudu_text_display_big`.

## Decimal (#802)

Decimal is an owned cell: `pudu_dec *`, member `decimal`, retained, released, rendered and ordered through its runtime.

## Indexed stores (#840)

CoreStoreType is an owned, aggregate `pudu_box *` mangled `BK_<held>_E`. Resolved Grill Log: a distinct mangle keeps store helpers apart from Map[Int, held] helpers in one program.

## Foreign handles (#853)

A foreign handle is an owned box whose C helper names include its nominal type identity.

## Callback token text (#956)

`callbackTokenText` emits the canonical declaration name in angle brackets
as an immutable text literal. Nested renderers call it for callback cells.

### Resolved Grill Log

Equality compares registration identities. Ordering uses the interpreter's
shared rank for callback values. Rendering needs only
the owner, so it remains available after registration teardown.

## Dynamic payload display (#956)

Member display retains text, converts a character to text, or selects the
payload's normal renderer.

### Resolved Grill Log

Both direct and erased carriers use the existing text and character helpers.
