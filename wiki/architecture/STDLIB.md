---
type: architecture
tags: [architecture, library]
aliases: [Standard Library, Stdlib Design]
---

# Standard Library Design

### Methods and module functions

A value has methods from exactly two places: the closed sets the compiler wires into `Array`,
`Str`, `Map`, `Set`, and `Char`, and the `impl` blocks a program writes. Everything else is a
module function taking the value as an argument.

That is why `text.contains("an")` works and `Option.unwrapOr(value, fallback)` does not become
`value.unwrapOr(fallback)`: `Str` is a built-in with a method set, and `Option` is an ordinary sum
type that nothing has implemented anything for. The rule is mechanical rather than a matter of
taste, but it is not guessable from the outside, so it is written here.

`E3033` catches the commonest form of the confusion in the other direction — asking a module for a
name it does not export, when the operation is a method on the value.

## Reading a format

`Std.Text.Parse` is a combinator library: a `Parser[T]` is `fn(Input) -> Step[T]`
and nothing more, so a reader writes their own primitives without asking the
module's permission. Two things decide whether it reaches a file rather than a
line.

**It carries the text it has not read yet.** Reaching the *n*th character of a
text walks past the first *n*, so a reader holding an index into the whole input
pays again for everything it has already passed and a scan costs the square of
the input. `Input` holds the remaining text; reading is always at the front and
advancing moves one character, both constant.

**A run is scanned against a set, not a character at a time.** `takeOf` and
`takeNotOf` name a set of characters — the same vocabulary `oneOf` and `noneOf`
already take — and consume the whole run in one step. A predicate written as a
function is a call for every character it is asked about, which for a quarter of
a megabyte is a quarter of a million calls; `takeWhile` keeps that form for a
rule a set cannot state. Reading the lines of a 257 KB file takes 0.65s through
the set form and 6.07s through the predicate.

**Choice commits.** A parser that failed *after* consuming does not fall through
to the next branch: the input it read is what said which branch was meant, and
trying another would report a problem from the wrong one. `attempt` opts out
where a format is genuinely ambiguous.

**A problem names a line.** `Problem` carries how many characters were consumed,
because counting lines on every step would charge every parse for an answer
almost none asks for. `explainIn` makes the count once, when a person is about
to read it, and says `line 3, column 1` rather than `position 18`.

## Decision

Pudu ships one **standard library** under the `Std` namespace, versioned with the compiler and
resolved without a network. It is not a package manager, a curated registry, or a batteries-optional
core: the modules below are part of the language distribution, and a program that imports them
compiles anywhere the compiler runs.

```pudu
module Report

import Std.Http as Http
import Std.Json {decode, encode}
import Std.Time {Instant, Duration}

export async fn fetch(url: Str) -> Result[Json, Http.Error] {
  let response = Http.get(url).timeout(Duration.seconds(30)).await?
  decode(response.body)
}
```

## Why a shipped standard library, and why now

Every language that deferred this decision paid for it twice. Ship a minimal core and the real
library surface — text, byte strings, containers, time, serialization, HTTP — ends up in packages a
beginner must discover, choose between, and pin. The discovery cost is real: a newcomer writing
their first HTTP call chooses between four clients with different error models, and the choice is
invisible in their source. Shipping everything early makes the opposite mistake: a standard library
whose oldest corners constrain what its newest ones can look like.

Pudu takes the middle position deliberately:

- **Shipped, so there is one answer.** `Std.Http` is *the* HTTP client. A reader of any Pudu program
  recognises it without checking a manifest.
- **Namespaced, so it can grow.** `Std.Http.Server` can arrive without disturbing `Std.Http`.
- **Versioned with the language, so it can be held to the same rules.** Every module below obeys the
  ownership, failure, and concurrency rules in [[architecture/SEMANTICS]]. A standard library that
  could opt out of them would make those rules advisory.

## The namespace split

| Root | Owner | Removable |
|---|---|---|
| wired-in types | the compiler | no |
| `Core.Prelude` | [[Semantic Prelude]] | shadowed by an explicit import |
| `Std.*` | the standard library | imported explicitly, always |
| anything else | the program | — |

`Core` holds what the language itself needs to describe its own semantics — the marker traits,
`Iterator`, the failure carriers. `Std` holds everything a program needs and the language does not.
The split matters because `Core` cannot be extended without changing the language definition, and
`Std` can.

## The modules

The shapes below are the ones decades of library design have converged on. Where Pudu departs from
the common shape, the reason is stated; where it does not, rediscovering the shape would cost years
and buy nothing.

### Data

| Module | Provides |
|---|---|
| `Std.Text` | Unicode text, slicing, builders, case folding, encode/decode |
| `Std.Bytes` | byte sequences, binary get/put, base64 and hex |
| `Std.List` | the operations `Array[T]` does not already carry |
| `Std.Map` | ordered maps, by comparison |
| `Std.Set` | ordered sets |
| `Std.HashMap` | hash maps, by `Hash`, in first-insertion order |
| `Std.Deque` | double-ended queue |
| `Std.Math` | numerics, saturating and checked arithmetic, constants |

| `Std.Uuid` | v4 and v7 identifiers |

### Time

| Module | Provides |
|---|---|
| `Std.Time` | `Instant`, `Duration`, `Date`, `TimeOfDay`, `Zoned`, arithmetic |
| `Std.Time.Format` | RFC 3339 and strftime-shaped parsing and rendering |

`Std.Time` separates a **`Instant`** (a point on the monotonic or system clock) from a **`Date`** (a
civil calendar value with no instant until a zone is applied). The distinction is the single most
common source of correctness bugs in date handling, and a library that blurs it makes them
unreportable.

### Text processing

| Module | Provides |
|---|---|
| `Std.Text.Parse` | parser combinators with position-carrying errors |
| `Std.Json` | `Json` values, decoding to declared types, streaming encode |
| `Std.Csv` | row and record decoding |
| `Std.Toml` | configuration values and encoding, read by `Std.Toml.Read` |

`Std.Text.Parse` is a combinator library rather than a regular-expression engine, and it now exists.
A regex is a second language embedded in a string, invisible to the type checker and to `pudu doc`;
a combinator parser is ordinary Pudu, so a malformed grammar is a compile error and a parser's type
says what it produces.

A `Parser[T]` is a plain function — `fn(Input) -> Step[T]` — not a type of its own, so every
combinator is an ordinary function and a caller can write their own without asking the module's
permission. Writing it needed generic type aliases, which did not work: an alias with parameters was
left nominal and unified with nothing.

Two decisions are worth naming. `orElse` does **not** fall through when its first branch failed
after consuming input: the input it read told it which branch was meant, and trying another would
report a problem from the wrong one — `attempt` is how a caller asks for backtracking anyway. And
`lazy` exists because a recursive grammar cannot be written without it: a rule mentioning itself
would build itself forever at the moment it was defined.

A regex module remains open — see the deferred list.

`Std.Json` keeps format mechanics behind one typed boundary. Its quoted-string loop does not know
the width or meaning of an escape: a private decoder returns the decoded scalar text and the first
unread source position. The admitted vocabulary is JSON's exact escape set, and UTF-16 surrogate
pairs are composed before entering Pudu's scalar strings. Unknown escapes, isolated surrogates, and
unescaped controls below U+0020 are `JsonError` values rather than permissive substitutions.
Encoding uses named escapes where JSON has them and `\u00XX` for the remaining controls.

### System

| Module | Provides |
|---|---|
| `Std.Io` | files, handles, streaming reads and writes |
| `Std.Path` | path construction and decomposition, platform-aware |
| `Std.Env` | arguments, environment, exit |
| `Std.Process` | subprocesses, pipes, exit status |
| `Std.Log` | structured, levelled, context-carrying logging |

### Network

| Module | Provides |
|---|---|
| `Std.Http` | client: requests, responses, redirects, timeouts, pooling |
| `Std.Http.Server` | server: reading requests off connections and answering them |
| `Std.Http.Server.Route` | which handler answers a request, and what it is given |
| `Std.Http.Server.Reply` | the answers a handler gives |
| `Std.Net` | addresses, TCP, UDP |
| `Std.Tls` | transport security for the above, verified against the machine's trust store |
| `Std.Url` | parsing, building, percent-encoding |

### Concurrency

| Module | Provides |
|---|---|
| `Std.Concurrent` | joinable host workers for blocking runtime work |
| `Std.Channel` | bounded and unbounded channels |
| `Std.Sync` | mutex, semaphore, once, atomic cells |

`Std.Concurrent` is currently a provisional host-worker layer, distinct from the deterministic cold
tasks used by `async fn`. Every worker is joinable and is registered for program teardown, but lexical
scope registration and cancellation are not complete; the module cannot be called stable until a
worker started inside `async with scope` is owned and joined by that scope rather than only by the
program. The distinction is explicit because calling raw threads "structured concurrency" would
claim a lifetime guarantee the evaluator does not yet enforce.

### Correctness

| Module | Provides |
|---|---|

| `Std.Bench` | timing with statistics, not one stopwatch reading |
| `Std.Crypto` | hashes, HMAC, constant-time comparison, secure random |
| `Std.Db` | typed SQL, parameter binding, transactions, connection pooling |
| `Std.Db.Session` | opening a connection and carrying one message across it |

## What ships today

Sixty modules and 1622 exported declarations are present in this recovery branch, every public
surface written in Pudu. Thirteen of those modules are provisional until the focused/full gates,
resource-lifetime audit, mirror review, and delivery split recorded in
[[2026-09-01-production-stdlib-recovery]] complete; presence is not a shipping claim.

| Module | Exports | Covers |
|---|---|---|
| `Std.List` | 97 | folds, scans, slicing, searching, set operations, zipping, sorting, subsequences, permutations, windows |
| `Std.Text` | 64 | slicing, splitting, padding, per-character work, prefixes, comparison, case |
| `Std.Map` | 47 | lookup, insertion, merging with rules, grouping, tallying, inversion |
| `Std.Set` | 39 | membership, set operations, subset tests, splitting, products |
| `Std.Bits` | 29 | the `Bits` trait and everything over it, each type answering for its own width |
| `Std.NonEmpty` | 29 | a sequence known to hold something, so `first`, `last` and `maximum` answer values |
| `Std.Deque` | 21 | a queue cheap at both ends, for breadth-first walks and scheduling |
| `Std.Heap` | 18 | a collection that always knows its smallest element, and the few smallest without a sort |
| `Std.Graph` | 22 | nodes and directed edges, topological order, cycles, components, shortest path |
| `Std.Tree` | 40 | a value with trees beneath it: three orders, paths, pruning, grafting, and growing |
| `Std.Mappable` | 3 | a trait over the container itself, so one definition serves several |
| `Std.SortedMap` | 31 | a map ordered by the caller's own comparison, with floor, ceiling, range, and rank |
| `Std.LinkedMap` | 27 | a map that iterates in the order its keys were first inserted |
| `Std.EnumMap` | 22 | a total map over a fixed key domain, whose `get` answers a value rather than an `Option` |
| `Std.BiMap` | 24 | a pairing read from either side, kept a bijection through every write |
| `Std.MultiMap` | 30 | many values under one key, where a key with no values does not exist |
| `Std.MultiKeyMap` | 24 | a two-part key with lookup by the whole key or by either part alone |
| `Std.LruCache` | 22 | a map with a capacity, discarding what has gone longest unused |
| `Std.PrefixTrie` | 25 | text keys held by their characters, so a prefix can be asked about |
| `Std.Num` | 15 | `Integer`, `Zero`, `One`, `Add`, `Sub`, `Mul`, `Div`, `Rem` and the aggregates over them |
| `Std.Iter` | 25 | `Sequence`, ranges and collection walks, plus lazy map/filter/take/drop/zip adapters |
| `Std.Decimal` | 30 | exact base-ten arithmetic, the seven rounding modes, scale control, the conversion path |
| `Std.Crypto` | 8 | SHA-256, UTF-8 encoding, constant-time comparison |
| `Std.Random` | 14 | a reproducible generator, ranges, shuffling, sampling |
| `Std.Text.Parse` | 69 | parser combinators with positions in their errors |
| `Std.Char` | 29 | ASCII classification, case folding, scalar conversion both ways |
| `Std.Math` | 27 | arithmetic, divisibility, roots, primality, checked partial operators — all bounded, none `Int`-only |
| `Std.Http` | 99 | methods, statuses, the standard header set, cookies, auth, negotiation, forms, ranges |
| `Std.Http.Message` | 11 | the wire format: parsing and rendering requests and responses, chunked bodies |
| `Std.Option` | 24 | transforming, filtering, collecting, and bridging to `Result` |
| `Std.Result` | 24 | transforming either side, collecting many results into one |
| `Std.Json` | 19 | a `Json` value, a decoder with positions in its errors, compact and pretty encoding |
| `Std.Url` | 16 | parsing, rendering, query handling, percent encoding, scheme ports |
| `Std.Order` | 27 | the `Ordering` type and comparisons built from it |
| `Std.Function` | 14 | identity, composition both ways, repeated and bounded application |
| `Std.Show` | 12 | rendering any value, arrays, options, results, and padded tables |
| `Std.Io` | 28 | files, directories, standard input and output, path handling |
| `Std.Out` | 22 | a printer as a value: separator, ending, prefix, and stream, with a pure rendering |
| `Std.Fmt` | 25 | a shaping spec as a value: width, fill, alignment, sign, grouping, radix, and columns |
| `Std.Test` | 43 | checks and suites as values, tables, conditions, and a report that says what failed |
| `Std.Test.Property` | 8 | generated values with shrinking, seeded so a failure repeats exactly |
| `Std.Log` | 36 | a logger as a value: level, name, carried fields, and a format, with a pure rendering |
| `Std.Env` | 17 | arguments and flags, environment variables, a place to write, stopping with a status |
| `Std.Time` | 40 | instants, durations, dates, times of day, formatting and parsing |
| `Std.Process` | 11 | running a program, its status and streams, availability |
| `Std.Bool` | 10 | the operators as functions, `select`, array folds |
| `Std.Tuple` | 10 | projection, exchange, per-side transformation, currying |
| `Std.Bytes` | 45 | compact bytes, binary reads/writes, slicing, hex, and base64 |
| `Std.Csv` | 12 | quoted separated rows, tables, records, and rendering |
| `Std.Path` | 23 | host-aware lexical construction, decomposition, and containment |
| `Std.Uuid` | 12 | byte-backed v4/v7 identifiers with explicit entropy and time |
| `Std.Bench` | 12 | repeated measurements, summaries, ratios, and rendering |
| `Std.Time.Format` | 17 | civil arithmetic, RFC 3339, HTTP dates, and patterns |
| `Std.Concurrent` | 7 | joinable host workers and parallel groups, provisional |
| `Std.Channel` | 9 | bounded typed queues with explicit closure, provisional |
| `Std.Sync` | 15 | runtime mutexes, atomic cells, and counters, provisional |
| `Std.Net` | 21 | TCP listeners/connections and bounded streaming reads, provisional |
| `Std.Http.Server` | 14 | limits, connection lifetime, and HTTP/1 serving, provisional |
| `Std.Http.Server.Route` | 26 | first-match routing, captures, query, and middleware, provisional |
| `Std.Http.Server.Reply` | 7 | the responses a handler builds without a request, provisional |
| `Std.Db.Protocol` | 24 | PostgreSQL v3 framing, authentication fields, rows, and binding, provisional |
| `Std.Db.Session` | 13 | connecting, SCRAM, and one message at a time, provisional |
| `Std.Db` | 25 | queries, rows, transactions, savepoints, and pools, provisional |

### On structures

`Std.List` and `Std.Map` cover what most programs hold. Four modules exist because the shape of the
data answers a question those cannot:

- **`Std.NonEmpty`** removes an `Option` that a caller already knew the answer to. `List.maximum`
  must answer `Option` because an array may be empty; a sequence that states it is not empty in its
  type pays that cost once, at the boundary, instead of at every call after it.
- **`Std.Deque`** is for the programs that take from the front. An array is cheap at its back and
  dear at its front, and a breadth-first walk or a scheduler does the dear thing on every step.
  Two arrays, the front one held reversed, make both ends cheap.
- **`Std.Heap`** is for wanting the next thing rather than everything in order. Keeping a whole
  collection sorted to read one element from it is paying for an answer nobody asked for.
- **`Std.Tree`** is one value with a sequence of trees beneath it — an outline, a menu, a syntax
  tree, a reporting line. Written by hand each time it is a record and a handful of walks that
  differ subtly between programs: one counts the root and another does not. It settles those once,
  and a node with no children is not a special case but a node whose sequence is empty, which is the
  `Option` a hand-written hierarchy carries at every branch. `foldTree` is the general fold the
  others are special cases of.
- **`Std.Graph`** is nodes and directed edges with the questions worth asking of them. Its
  topological order answers `Option`, and `None` means a cycle — a caller ordering build steps or
  resolving declarations needs to be told its input is circular rather than handed an order that
  quietly is not one.

Three more exist because `Map` answers one question — what is under this exact key — and these are
the three next-commonest questions asked of a keyed collection:

- **`Std.SortedMap`** answers about a key's *neighbours*: the largest key not greater than this one,
  the entries between two bounds, the tenth entry. A rate table, a version range, and a histogram
  bucket all ask that, and `Map` can only answer by reading every entry out and scanning. It also
  takes the comparison from the caller, so ordering by a record's field or downwards is expressible
  at all, which it is not against the runtime's own order on values.
- **`Std.LinkedMap`** answers *what order were these put in*. [[Eval Keyed]] settled deliberately
  that the built-in map is not insertion-ordered, because two maps with the same entries must be the
  same map, and recorded that a separate ordered-map type remained open. This is that type, for the
  programs that hand something back to a person in the order somebody wrote it.
- **`Std.EnumMap`** removes an `Option` the caller already knew the answer to, which is the same
  thing `Std.NonEmpty` does for a sequence. Over a fixed domain of keys — the days of a week, the
  levels of a log — every key has a value by construction, so `get` answers `V`.
Three more again, because `Map` is one-directional and single-valued, and because questions may
only be asked of its key:

- **`Std.BiMap`** is a pairing rather than a mapping — a currency code and its symbol, a user and
  their session — where which side is the key depends on which way the program is going. It also has
  to answer what `Map` never does: a value can collide the way a key can, so `insert` displaces the
  earlier binding to keep both directions total, and `insertChecked` reports instead for callers
  whose input was meant to be a bijection already.
- **`Std.MultiMap`** keeps a grouping rather than building one, which is the half `Map.groupBy` does
  not do. Its rule is that a key with no values does not exist: the bookkeeping people write by hand
  usually forgets to remove the key when its last value goes, leaving a key `containsKey` answers
  true for and `get` answers nothing for.
- **`Std.MultiKeyMap`** is justified only by *partial* lookup. Composite keys already work —
  `Map[(A, B), V]` is valid, since the runtime's order handles tuples — so a caller who only wants
  the value under a whole pair should write that. What a pair-keyed `Map` cannot do is answer about
  one part of the key without reading every entry, and that is what the two indexes here buy, at the
  price of maintaining them on every write.

And two whose shape is about what a collection refuses to do rather than what it holds:

- **`Std.LruCache`** is a map with a bound, because a cache without one is a map that only grows.
  It discards by least recent *use*, so reading keeps an entry alive — which is why its `get`
  answers a cache alongside the value, since a read that did not record itself would let an entry
  the program depends on be discarded as unused. It is built on `Std.LinkedMap`'s recency order
  rather than repeating it.
- **`Std.PrefixTrie`** holds text keys by their characters, so walking a prefix touches one node per
  character of the prefix rather than one per entry in the collection, and a stem shared by many
  keys is stored once. Autocomplete, a routing table's most specific match, and every setting under
  one section are the questions; `Map` answers them by testing every key.

**`Std.HashMap`** is the last of them, and it needed a language decision before a
container: [[ADR-0015]] settles that `Hash` sits beside `Eq` and `Ord`, that equal values must
hash alike while alike hashes need not be equal, and that identity is always decided by `Eq`.
The buckets are reached through a runtime store keyed by a number rather than by comparison,
because buckets held in the ordered `Map` would pay an ordered lookup for every hashed one —
which is the cost the container exists to remove. Enumeration is first-insertion order, kept by
the entries themselves, so what a program prints does not depend on where a bucket landed.

None of them is a primitive. Each is built from what is already here, which is the test of whether
the existing surface is enough to write against.

### On lookup tables

`Http.reasonFor` maps thirty-one status numbers to their reasons. `methodFrom`, `versionFrom`,
`isHopByHop` and `Url.defaultPort` do the same for smaller sets. All five are tables, and all five
are written as tables: a `const` at module scope, read by a lookup.

Getting there took three attempts and two wrong answers, so the measurements are recorded rather
than the conclusion alone. 20000 lookups at `-O0`, process launch and loop overhead subtracted:

| lookup | nested `if` ladder | flat `match` | `const` table |
|---|---|---|---|
| code 200, third in the table | 325 ms | 167 ms | 228 ms |
| code 404, seventeenth | — | 384 ms | **236 ms** |
| code 500, twenty-sixth | — | 520 ms | **230 ms** |
| code 504, last | 2255 ms | 586 ms | **232 ms** |
| an unnamed code | 2268 ms | 598 ms | **212 ms** |

The `const` table is the only one of the three whose cost does not depend on where in the table the
answer sits. A ladder and a `match` both walk, so both get slower the further down the answer is and
slower again as the table grows; the table does not. Only the very first entries favour a `match`,
and a status table is not read at its first entries — `404` and `500` are.

**The `const` is what makes it a table.** A `Map` built inside the function is rebuilt on every
call, and measured that way it loses to both other forms; that is the trap, and it is why the first
two attempts here went the way they did. A module-scope `const` is evaluated once, which the flat
figures above are the evidence of.

### On numbers

`Std.Order` now carries `Hash` beside `Eq` and `Ord`. The law runs one way: two values that are
equal must hash alike, and two that hash alike need not be equal. A hash is not a digest and
promises nothing across runs — `Std.HashMap` mixes it against a value the process chose at startup,
so a caller who picks keys cannot pick which of them collide.

The numeric surface is **generic, bounded by traits**, not `Int`-only. `Std.Order` carries `Eq` and
`Ord`, `Std.Num` carries `Integer`, `Zero`, `One`, `Add`, `Sub`, `Mul`, and `Div`, and `Std.Bits` carries
`Bits` — each implemented across the integer family and, where it makes sense, both floating widths
and `Str`, `Char`, and `Bool`.

`Integer` is the whole-number boundary the other numeric traits cannot express: floats can add and
order, but they are not integer ranges or integer parser results. It converts through `BigInt`
without losing the caller's width or signedness, and conversion back is fallible rather than
truncating.

### `Std.Iter`

`for item in value` had only ever worked for shapes the evaluator knew by name. `Std.Iter` is the
trait that opens it to anything:

```pudu
export trait Sequence[S, T] {
  fn begin(self: &Self) -> S
  fn advance(self: &Self, state: S) -> Option[(S, T)]
}
```

The state is **passed rather than mutated**, which is the decision the rest of the module follows
from. An iterator is then an ordinary value: it can be held, copied, and walked twice, and both
walks see the same items. A protocol built on a mutable cursor would make an iterator the one value
in the language that quietly changes when you look at it.

`Range[N]` is bounded by `Integer` as well as the operations it uses, so a caller counting in
`UInt8` stays in `UInt8` while a floating range is rejected. `Items[T]`, `Indexed[T]`, and
`Repeated[T]` carry the caller's own element type. The `Int` values that remain are positions,
yielded counts, and take/drop limits — quantities defined by the walk, not values whose width the
caller selected. Fixing an element or range value to `Int` would repeat the mistake [[ADR-0006]]
was written to stop.

The functions over sequences are bounded by the trait rather than written per type, so `toArray`,
`count`, and `isEmpty` work for every sequence a program will ever declare:

```pudu
export fn toArray[S, T, Q: Sequence[S, T]](source: &Q) -> Array[T]
```

The adapters — `map`, `filter`, `take`, `drop`, `zip` — are themselves sequences over other
sequences, which is what makes [[grammar/pudu]]'s "iterator adapters are lazy" true rather than
aspirational. Building one does no work; `advance` does one item's worth and returns. That is what
lets an endless sequence be used at all:

```pudu
let evens = I.filter(I.map(naturals, triple), isEven)
for n in I.take(evens, 4) { ... }        // ends
```

Each adapter is an ordinary `impl` bounded by `Sequence` on its source, so nothing about them is
special to the library: a program can write its own the same way.

`map`, `filter`, `take`, `drop`, and `zip` are lazy adapters: construction performs no traversal,
and each `advance` asks only for the source work needed for its next answer. `count`, `isEmpty`, and
`sum` traverse without first materialising an array; `isEmpty` asks for at most one item, and `sum`
returns `Option` because an empty sequence provides no value from which to obtain its additive
identity.

### `Std.Decimal`

`Decimal` is the type money is written in, and the reason it stayed unusable so long is that a
decimal type is not a representation choice but a rounding policy. [[ADR-0007]] settles it: a value
is a coefficient and a base-ten scale, addition, subtraction, and multiplication are always exact,
and division is exact or an error. `1d / 3d` reports `E7010` instead of quietly producing a number
that is not the quotient.

That makes the module's shape unusual in a useful way. Most of its thirty exports are ordinary —
`sum`, `mean`, `abs`, `floor` — but every operation that could lose a digit takes the precision and
the mode as arguments, because there is no context to inherit them from:

```pudu
D.divide(total, count, 2, D.HalfEven)   // Option[Decimal]; None only for a zero divisor
D.rescale(total, 2)                     // says the answer is in cents and means it
```

The `Rounding` sum lives here rather than in the compiler, and the primitives underneath take a
plain integer code, because a wired-in signature cannot mention a type a library module declares.
That split is deliberate: the compiler owns exactness, and the library owns the vocabulary a program
reads.


`Bits` has no implementation for `BigInt`, because `BigInt` has no width and every operation there
needs one. That is the bound doing its job: the type that cannot answer is the type that is refused.

`width` is a method, so a value answers for its own rather than a module assuming sixty-four:
`countLeadingZeros(1u8)` is 7 and `countLeadingZeros(1u32)` is 31.

See [[decisions/ADR-0006-integer-widths-and-std-numerics]] for what had to be fixed underneath —
integers had no width at run time at all — and for what `Std` promises about numbers.

### On hashing, and why it is written in Pudu

`Std.Crypto`'s SHA-256 is written in the language, not wrapped from the runtime. It produces
byte-exact digests for the algorithm's published vectors, which is only possible if rotations,
wrapping addition, and thirty-two bit masking are all exactly right — so it is the strongest
available evidence that [[decisions/ADR-0006-integer-widths-and-std-numerics]]'s work is correct
rather than merely present.

Its UTF-8 encoder is in the language for the same reason: it is bit work Pudu can express, and a
standard library that reached past the language for it would be saying the language could not.

Two comparisons are constant-time — `digestsMatch` and `secretsMatch` — because a comparison that
stopped at the first difference would report, in how long it took, exactly where two secrets
diverged. That is how a token is guessed one character at a time.

**What is not here:** a password hash, a cipher, a signature, or a random source fit for a secret.
`Std.Random` is reproducible on purpose and seeded from a readable clock, which makes it right for a
simulation and wrong for a key. Those need review this project has not had, and shipping them
unreviewed would be worse than not shipping them.

### On effects

`Std.Io` and `Std.Env` are real: a program reads and writes files, lists directories, reads its
arguments and environment, and stops with a status. Every effect answers with `Result[T, Str]`
carrying what the operating system said, because the language has no exceptions and a missing file
is an outcome a caller handles.

**Nothing about the machine is written down.** Where a program may put a file it does not intend to
keep, which directory is the reader's own, and which characters separate the pieces of a path and
the entries of a search path are all asked of the machine at the moment they are needed. Each of
those differs between operating systems, and one spelled into the source is a claim about somebody
else's computer — a program that writes `/tmp` will not run where that path does not exist, and one
that joins with a slash builds something that is not a path where the separator is a backslash.
This is why they are effects rather than constants: a folded answer would be the *compiling*
machine's, which is not the one that runs.

**A constant may not reach the world.** Compile-time folding runs the same evaluator with effects
denied and reports `E7009`. Compilation that depended on the world the compiler happened to be in
would not be compilation.

`Std.Time` separates an **`Instant`** from a **`Duration`** from a **`Date`**, each its own type.
That distinction is the one date handling gets wrong most often — a birthday is a date everywhere,
while a meeting is an instant — and a library that let them be added together would be inviting the
mistake rather than preventing it.

The interpreter now has narrow host boundaries for file handles, sockets, workers, synchronization,
and cryptographic primitives. They are not a general foreign interface: Pudu source cannot name a C
symbol, invent a resource token, or assert host ownership. That restriction lets `Std.Net`,
`Std.Http.Server`, and the PostgreSQL-specific `Std.Db` exist without prematurely settling
`Std.Ffi`; every host exception is translated into the library's declared `Result` error.

### On HTTP

`Std.Http` and `Std.Http.Message` carry everything about the protocol that does not touch a socket:
building and inspecting requests, the full status and header vocabulary, cookies, basic and bearer
authorization, content negotiation with weights, form bodies, byte ranges, chunked framing, and
parsing or rendering a complete message.

`Std.Http.Server` now joins that protocol surface to `Std.Net`: handlers remain socket-free values,
routes are first-match, and the reader enforces explicit head/body limits before materializing a
request. The HTTP client transport is still absent. A client must add redirects, deadlines, response
limits, connection reuse, and TLS verification rather than expose a `send` that only works for the
happy path.

## What writing it found

The design says the library is written **in Pudu** precisely so that every place it cannot be is a
place the language is missing something. Writing these nine modules found nine such places, and each
one became a language change rather than a workaround:

| What the library could not write | What the language gained |
|---|---|
| `items[0]` on a `&Array[T]` | indexing follows a borrow |
| matching on a `&Option[T]` | a match reads through a borrow |
| any text operation at all | `Str` gained seventeen built-in methods |
| `map`, `filter`, `sortBy` | function literals with capture |
| joining two arrays | `Array.concat`, structural rather than a loop |
| an integer as a character | `charFromCode` in the prelude |
| a character as text | `Char.toText` |
| documentation on an exported name | doc comments attach past modifiers |
| `out.push(x)` doing nothing | `W3002` for a discarded collection result |
| any keyed collection | `Map` and `Set` as wired-in types |
| `Ok(())` against `Result[(), E]` | an empty tuple types as unit |
| a brace in a string literal | `\{` escapes one, keeping `{` reserved |
| rendering any value as text | `show` in the prelude |

One of them was a soundness bug rather than a gap: `(Int, Str)[1]` reported `Int` while the value
was text, because a tuple's members were all typed as the first member's type. A tuple is now
indexed by a literal position, and `E3027` reports anything else.

## What "production ready" is required to mean

These are constraints on every module above, and a module that cannot meet one does not ship.

**No partial functions.** Nothing in `Std` panics on an input a caller could have. `head` returns
`Option[T]`. Division returns `Result[T, DivisionByZero]`. A function that can only fail through a
defect in its own implementation may panic, and says so in its documentation.

**Failure is in the type.** Every fallible operation returns `Result` with a declared error type.
No module raises, and none returns a sentinel value. An error type is a sum with one variant per
distinguishable cause, because a caller that cannot distinguish causes cannot recover from any of
them.

**Resources are owned.** Every handle, connection, and pool obeys `Drop`. There is no `close` a caller
can forget, and no finaliser that runs at an unspecified time.

**Cancellation is honoured.** Every blocking operation in `Std.Io`, `Std.Http`, `Std.Net`, and
`Std.Db` is cancellable and is cancelled when its enclosing scope unwinds. An operation that cannot
be cancelled takes a deadline.

**Streaming before buffering.** `Std.Io`, `Std.Http`, and `Std.Json` expose a streaming interface
first and a convenience "read it all" wrapper second. A library whose only interface materialises the
whole input decides the memory profile of every program that uses it.

**No hidden allocation in a hot path.** `Std.Text` and `Std.Bytes` slice without copying, and every
operation that must copy is named so the reader can see it.

**Documented with `///`.** Every exported name carries documentation, so `pudu doc` and `pudu search`
answer for the standard library as they do for a program. This is checkable and will be checked.

The provisional recovery modules do not yet satisfy every rule above. In particular, opaque handles
are closed explicitly plus at program teardown rather than by implemented `Drop`, and blocking host
operations do not yet have scope cancellation/deadlines. They remain implementation candidates, not
production-ready exceptions to these rules.

## Import DX

The forms are the ones [[grammar/pudu]] already admits; the standard library adds no syntax.

```pudu
import Std.Http                      // qualified: Std.Http.get(...)
import Std.Http as Http              // aliased:   Http.get(...)
import Std.Json {decode, encode}     // selective: decode(...)
import Std.Time {Instant}            // one name
```

Three rules govern which to reach for, and they are conventions rather than checks:

- **Alias a module you use throughout.** `import Std.Http as Http` keeps `Http.get` readable and keeps
  the origin visible at every call.
- **Select names you use as vocabulary.** `import Std.Json {decode}` is right when `decode` reads as a
  verb in your own domain.
- **Never import for brevity alone.** A selective import that makes a name ambiguous with one of your
  own is worse than the qualified form it replaced.

Wildcard imports stay prohibited, for the standard library as for everything else: a reader must be
able to answer "where did this name come from" from the import list alone.

## Resolution

`Std.*` resolves from the compiler's own distribution, not from the source root. The lookup order is:

1. The program's source root, so a program **can** shadow a standard module — deliberately, and
   visibly, since the file is in its own tree.
2. The distribution's library root.

There is no third step. No network, no cache, no lock file, no version solving. A Pudu program's
dependencies are its own files plus the compiler it is built with, and that is the whole answer.

## Active completion queue

- ~~**`Std.HashMap` and `Hash`.**~~ Shipped; see [[ADR-0015]]. The remaining note is kept only as
  the record of what had to be settled first: equality/hash coherence and a
  constant-time indexed bucket representation must be specified beside `Eq` and `Ord` before the
  public map is written. A tree of buckets would still be an ordered map plus hashing and is refused.
- ~~**`Std.Toml`.**~~ Shipped, split three ways: values and encoding in `Std.Toml`, document
  structure in `Std.Toml.Read`, and the lexical layer in `Std.Toml.Scan`. Numbers and moments keep
  their source text rather than being rounded or given a zone. The note below is the record of what
  it had to preserve: line/column diagnostics, duplicate-key and
  dotted-table rules, and a deterministic value model. It is library work, not syntax.
- ~~**`Std.Tls`.**~~ Shipped. The protocol is not written in Pudu and not written in this
  repository: transport security is the one place here where being wrong is silent, since a
  handshake that skips a check still completes and still carries traffic. It reaches a reviewed
  implementation the way sockets reach the system's own, and what the library owns is the part that
  must not be defaulted — verification on with no argument to disable it, the machine's trust store
  as the authority, and the caller's own name as the name to prove.
- **Project/package tooling.** A manifest, lockfile, content-addressed cache, deterministic resolver,
  offline build, checksums, and compatibility rules must precede any registry publication. The
  standard library remains shipped and cannot be shadowed by dependency resolution.
- **Large-input evidence.** File, network, CSV/TOML/JSON, HTTP, and database readers need streaming
  fixtures whose maximum residency is bounded independently of input size; a buffered convenience
  wrapper never serves as that evidence.

## Deferred, with reasons

- **`Std.Regex`.** A regular-expression engine is a second language inside a string literal. Before
  admitting one, Pudu needs to decide whether it can be checked at compile time — a literal pattern
  can be, a computed one cannot — and shipping the unchecked form first would settle that question by
  default.
- **`Std.Ffi`.** Calling into C requires the `foreign` capability from [[Unsafe Capabilities]] and a
  decision about how a foreign type's ownership is described. Both are open.
- **Numeric tower beyond `BigInt` and `Decimal`.** Rationals and arbitrary-precision floats have real
  uses and no urgent one; admitting them later costs nothing, and admitting them wrongly costs a
  release.

## Grill Log

- **Q:** Why not ship a minimal core and leave the rest to packages? **A:** Because the discovery
  cost is paid by every newcomer and the fragmentation cost is paid by every reader. Where that split
  exists elsewhere it is usually historical rather than designed — an early type that could not be
  removed, so its replacement had to live outside — and inheriting the outcome without the history
  would be inheriting a constraint Pudu does not have. _Rejected:_ a minimal core plus a curated
  "platform" list, which is the same fragmentation with a blessing attached.
- **Q:** Why not put these under `Core` alongside the prelude? **A:** Because `Core` names what the
  language definition depends on, and a change there is a change to the language. `Std.Http` must be
  able to gain a method without that being true. _Rejected:_ one flat namespace.
- **Q:** Should `Std` modules be implicitly imported like the prelude? **A:** No. The prelude is
  implicit because the language's own semantics mention its names; nothing in the language mentions
  `Std.Http`. An implicit import would also make every program's namespace depend on the compiler
  version. _Rejected:_ implicit `Std.Text`, which is the most tempting single case and still wrong
  for the same reason.
- **Q:** Should the standard library be written in Pudu or built into the compiler? **A:** In Pudu,
  except where a primitive is unavoidable. A standard library written in the language is the strongest
  available evidence that the language is usable, and every place it cannot be is a place the language
  is missing something. Unavoidable primitives are `unsafe` functions in `Std` with a named
  capability, so the boundary is visible. _Rejected:_ a compiler-internal library, which hides exactly
  the feedback this project needs.

## Referenced by

[[architecture/_MOC]] · [[grammar/pudu]] · [[Semantic Prelude]] · [[architecture/SEMANTICS]]
