---
type: module
path: "@root/lib/Std/Db/Store.pudu"
fidelity: Active
domain: "[[Standard Library]]"
subsystem: "[[architecture/STDLIB]]"
tags: [module, stdlib, database, mapping, orm]
aliases: [Std Db Store]
---
# Std Db Store
## Purpose
Keep a program's own values in a database and get them back, without any of them pretending to be
something they are not.
## Interface
How a kind of value is stored: its table, its key, the columns it occupies, how it becomes a row,
and how a row becomes it. Saving one, changing one, removing one. Loading one by key, or every one a
statement chooses. Loading what belongs to several parents at once, as a map from each parent's key
to what belongs to it. Counting. What a refusal says.
## Governance and algorithm
**A loaded value is a value.** It holds what was loaded and nothing else: no proxy, no attached
session, no field that will fetch something the first time it is read. That single decision is what
removes the four failures this layer is otherwise known for, and it removes them by construction
rather than by advice.

*Reading a relation after the session closed* cannot happen, because nothing is left unread. The
established framework's most common error is exactly this, and every remedy for it is a way of
arranging for the session to still be open — which is why the setting that keeps it open for the
whole of a request is on by default there and is, by wide agreement, wrong in production. There is
no session here to hold open and no setting to get wrong.

*Writing at a moment nobody chose* cannot happen, because nothing is written unless a program says
to write it. There is no dirty tracking, so there is no flush, so there is no question of when it
happens.

*One query becoming a hundred* is made hard rather than impossible, and the way it is made hard is
the shape of the interface: what belongs to a parent is loaded for **many parents at once** and
answers a map. Loading for one parent is loading for a list of one. So the batched form is the
ordinary form and the form that issues a query per parent is the one somebody has to write a loop
to produce. Established practice offers both and makes the slow one the default, which is why the
problem is famous.

**Mapping is stated in both directions and neither is derived.** A row becomes a value by a function
somebody wrote, and a value becomes a row the same way. Nothing reads a class to guess a column, so
renaming a field is not a silent change to a schema, and the mapping can be checked by comparing
values with no database present.

**The key is part of what it means to be stored.** A kind of value that is stored says which column
identifies it, because loading, changing, and removing all need it and a layer that guessed would
guess differently in each.
## Grill Log
- **Q:** Load a relation when it is first read, as the established framework does? **A:** No.
  _Rationale:_ that is the one decision that produces its three best-known failures — an exception
  when the session has closed, a query per parent, and a setting that keeps sessions open across a
  whole request to hide the first two. A value that holds what was loaded has none of them.
  _Rejected:_ lazy associations; proxies.
- **Q:** Track changes to loaded values and write them automatically? **A:** No. _Rationale:_ then
  when a write happens is decided by the framework, and the answer is "somewhere before the
  transaction ends", which is not a place a reader can point at. _Rejected:_ dirty checking;
  automatic flush.
- **Q:** Offer both a single-parent and a many-parent relation load? **A:** The single one is
  defined as the many one with a list of one, so there is one implementation and the batched shape
  is what everything goes through. _Rationale:_ offering both as peers is how the slow one becomes
  the default. _Rejected:_ a separate per-parent path.
- **Q:** Keep an identity map so the same row loaded twice is the same value? **A:** No.
  _Rationale:_ it is a cache with an invalidation problem, and it makes two reads of the same row
  return something that may be neither of them. Values compare by what they hold. _Rejected:_ a
  first-level cache.
- **Q:** Derive the column list from the shape of the value? **A:** No — that needs reflection this
  language does not have, and where it exists it turns renaming a field into a schema change nobody
  reviewed. _Rejected:_ derived mappings.
## Referenced by
[[src/Std/_MOC]] · [[Std Db Schema]] · [[Std Db Query]] · [[Std Db Repository]] · [[Std Db Session]]
