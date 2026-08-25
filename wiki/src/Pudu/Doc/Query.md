---
type: module
path: "@root/src/Pudu/Doc/Query.hs"
fidelity: Active
domain: "[[Pudu Program]]"
subsystem: "[[Tooling]]"
grammar: "[[grammar/haskell]]"
depth_score: 0.4
depth_status: SHALLOW
coupling: 1.0
interface_stability: 0.7
tags: [module, shallow]
aliases: [Doc Query]
---

# Doc Query

## Purpose

Read what a reader typed into either a name or a type shape.

## Interface

### Signatures

```haskell
data Query = NameQuery !Text | TypeQuery !Signature
parseQuery :: Text -> Maybe Query
renderQuery :: Query -> Text
```

### Governance

- A query is a name or a type. Nothing else is admitted: a query language that grew predicates
  would need its own grammar, errors, and documentation, and these two forms answer the two
  questions a reader has — "where is this thing" and "what has this shape".
- A query containing `->` is a shape; anything else is a name. That is the whole disambiguation
  rule, and it is deliberately syntactic, so a reader never has to say which they meant.
- An applied type with no arrow — `Array[Int]` — is a name query. A bare capitalised word is far
  more often a type the reader wants to find than a nullary signature to match. `-> Array[Int]`
  asks for the shape.
- A lowercase-leading name is a variable and an uppercase one is a nominal type. Query text is not
  source, so there is no declaration to consult, and this is the convention readers already type.
- A function-typed argument must be parenthesised: `(fn(Int) -> Str) -> Bool`. An unparenthesised
  one is genuinely ambiguous with the query's own arrows, and guessing would answer a different
  question than the one asked.
- Parsing is total and never reports a diagnostic. A query that does not parse is not an error in
  a program; it is a reader who has not finished typing.
- Query text is capped at 512 Unicode scalars and 64 nested bracket/parenthesis levels before
  recursive parsing. Exceeding either budget is an unfinished query, not a compiler failure.

### Linkage

- **Requires:** [[Doc Signature]].
- **Consumed by:** [[Doc Search]], [[Doc Site]].

## Algorithm

Split on arrows outside brackets and parentheses, discard one empty leading piece when the query
starts with an arrow, parse every remaining piece as a type atom, and take the last piece as the
result.

## Negative Logic (Prohibited Paths)

- No use of the language's own lexer or parser: a query is not source, and admitting source syntax
  would promise support for constructs the search cannot compare.
- No diagnostics, no partial results, and no invented result for a trailing arrow.
- No unbounded recursive descent over pasted interactive input.

## Edge Cases

- `Int ->` does not parse: the reader was still typing, and inventing a result answers a question
  they did not ask.
- `-> Config` has no arguments and `Config` as its result. Only the first empty piece has that
  meaning; `Int -> -> Config` remains malformed.
- A query beyond the scalar or nesting budget yields no query and therefore no matches.
- A parenthesised group with top-level commas is a tuple; without them it is a grouping, matching
  how the language reads parentheses.

## Depth

DEPTH 0.40 (SHALLOW by intent). One disambiguation rule and a small recursive descent.

## Grill Log

- **Q:** Should the query language support Hoogle's `Ord a => [a] -> [a]` constraint syntax?
  **A:** Not yet. _Rationale:_ ranking already prefers signatures whose shape matches, and a reader
  who names a bound is usually naming the trait, which the name query already finds. Admitting the
  syntax would mean deciding what a *missing* constraint implies about a match, which has no
  obviously right answer. _Rejected:_ parsing and ignoring constraints, which silently answers a
  different question.

## Referenced by

[[src/Pudu/Doc/_MOC]] · [[Doc Search]] · [[Doc Site]]
