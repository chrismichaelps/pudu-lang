---
type: module
path: "@root/src/Pudu/Doc/Search.hs"
fidelity: Active
domain: "[[Pudu Program]]"
subsystem: "[[Tooling]]"
grammar: "[[grammar/haskell]]"
depth_score: 0.6
depth_status: MEDIUM
coupling: 2.0
interface_stability: 0.7
tags: [module, medium]
aliases: [Doc Search]
---

# Doc Search

## Purpose

Rank a documentation index against one query, best answers first.

## Interface

### Signatures

```haskell
data Match = Match { matchEntry :: !DocEntry, matchScore :: !Int }
searchIndex :: Query -> DocIndex -> [Match]
searchText :: Text -> DocIndex -> [Match]
```

### Governance

- A constructor name matches on its last segment when the query is unqualified: a reader searching for `Circle` should find `Shapes.Circle`, because they are asking about a type rather than about where it was declared. A query that qualifies is matched in full, so a reader who knows the module can still say so.

- The score is exposed rather than hidden in the ordering, so a caller merging results from several
  modules can rank them together instead of re-deriving a comparison it was already given.
- A query that matches nothing scores nothing. A bad match at the bottom of a list is still a claim
  that it matched.
- Name ranking is exact, then prefix, then infix, then scattered subsequence — the order in which a
  reader's confidence decreases.
- Shape ranking is exact, then reordered arguments, then the query's arguments contained in a longer
  list with the same result, then the result alone. The last is the weakest honest answer: "this
  produces what you asked for".
- A variable in the **signature** accepts anything, because that is what polymorphism means. A
  variable in the **query** matches only another variable: a reader who wrote `T -> T` asked for a
  function that works for every type, and `Int -> Int` is not one.
- `SigUnknown` matches in either direction. It means the compiler could not say, and refusing to
  match would hide the entry rather than qualify it.
- Ties keep declaration order, so a module's own arrangement survives when ranking has nothing
  to say.

### Linkage

- **Requires:** [[Doc Index]], [[Doc Query]], [[Doc Signature]].
- **Consumed by:** [[Pudu REPL]], [[Pudu CLI]], [[Doc Site]].

## Algorithm

Score every entry, drop the ones that did not match, and sort by score. Argument containment is a
greedy consumption of the available arguments, which is exact for the arities a signature has.

## Negative Logic (Prohibited Paths)

- No unification and no substitution: matching is structural compatibility, not inference.
- No fuzzy matching on type names — `Array` does not match `Arrays`. A type name is an identity,
  and a near-miss there is a different type, not a near answer.
- No ranking by module, popularity, or declaration count: the index describes one program, and
  inventing authority between its modules would be arbitrary.

## Edge Cases

- A query with no arguments and a result matches anything producing that result, which is how a
  reader asks "what gives me a `Config`?".
- `SigNever` matches anything: a function that does not return can stand where any result is
  wanted.

## Depth

DEPTH 0.60 (MEDIUM). Two ranking ladders, each rung justified.

## Grill Log

- **Q:** Should a polymorphic query match a concrete signature? **A:** Only through the weaker
  rules. _Rationale:_ `T -> T` genuinely does not describe `Int -> Int` to a caller who needed it
  for `Str`, so ranking it as an exact answer would mislead. _Rejected:_ symmetric matching, which
  makes every polymorphic query match everything of the same arity.
- **Q:** Should results be capped inside search? **A:** No. _Rationale:_ a prompt wants a screenful
  and a documentation site wants all of them; the cap belongs to the caller that knows its medium.
  _Rejected:_ a fixed limit here.

## Referenced by

[[src/Pudu/Doc/_MOC]] · [[Doc Index]] · [[Doc Site]]
