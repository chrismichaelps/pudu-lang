---
type: architecture
tags: [architecture, library]
aliases: [Standard Library, Stdlib Design]
---

# Standard Library Design

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
| `Std.HashMap` | hash maps, by `Hash` |
| `Std.Deque` | double-ended queue |
| `Std.Math` | numerics, saturating and checked arithmetic, constants |
| `Std.Fmt` | typed formatting, no format-string interpretation at run time |
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
| `Std.Toml` | configuration |

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
| `Std.Http.Server` | server: routing, handlers, middleware |
| `Std.Net` | addresses, TCP, UDP |
| `Std.Tls` | transport security for the above |
| `Std.Url` | parsing, building, percent-encoding |

### Concurrency

| Module | Provides |
|---|---|
| `Std.Concurrent` | task groups over the language's own `async with scope` |
| `Std.Channel` | bounded and unbounded channels |
| `Std.Sync` | mutex, semaphore, once, atomic cells |

`Std.Concurrent` is a thin layer over the structured scopes the language already has. It does not
introduce a second concurrency model: a task started through it is a child of the enclosing scope and
is joined by the same rules, so the library cannot leak a task the language would have caught.

### Correctness

| Module | Provides |
|---|---|
| `Std.Test` | assertions, property generation, shrinking |
| `Std.Bench` | timing with statistics, not one stopwatch reading |
| `Std.Crypto` | hashes, HMAC, constant-time comparison, secure random |
| `Std.Db` | typed SQL, parameter binding, connection pooling |

## What ships today

Twenty-eight modules, 807 documented exports, every one written in Pudu.

| Module | Exports | Covers |
|---|---|---|
| `Std.List` | 95 | folds, scans, slicing, searching, set operations, zipping, sorting, subsequences, permutations, windows |
| `Std.Text` | 64 | slicing, splitting, padding, per-character work, prefixes, comparison, case |
| `Std.Map` | 47 | lookup, insertion, merging with rules, grouping, tallying, inversion |
| `Std.Set` | 33 | membership, set operations, subset tests, splitting, products |
| `Std.Bits` | 27 | the `Bits` trait and everything over it, each type answering for its own width |
| `Std.Num` | 24 | `Zero`, `One`, `Add`, `Sub`, `Mul`, `Div`, `Rem` and the aggregates over them |
| `Std.Iter` | 15 | the `Sequence` trait `for` walks, and the sequences over ranges, arrays, and repetition |
| `Std.Decimal` | 30 | exact base-ten arithmetic, the seven rounding modes, scale control, the conversion path |
| `Std.Crypto` | 8 | SHA-256, UTF-8 encoding, constant-time comparison |
| `Std.Random` | 14 | a reproducible generator, ranges, shuffling, sampling |
| `Std.Text.Parse` | 41 | parser combinators with positions in their errors |
| `Std.Char` | 29 | ASCII classification, case folding, scalar conversion both ways |
| `Std.Math` | 27 | arithmetic, divisibility, roots, primality, checked partial operators — all bounded, none `Int`-only |
| `Std.Http` | 74 | methods, statuses, the standard header set, cookies, auth, negotiation, forms, ranges |
| `Std.Http.Message` | 12 | the wire format: parsing and rendering requests and responses, chunked bodies |
| `Std.Option` | 24 | transforming, filtering, collecting, and bridging to `Result` |
| `Std.Result` | 24 | transforming either side, collecting many results into one |
| `Std.Json` | 19 | a `Json` value, a decoder with positions in its errors, compact and pretty encoding |
| `Std.Url` | 16 | parsing, rendering, query handling, percent encoding, scheme ports |
| `Std.Order` | 16 | the `Ordering` type and comparisons built from it |
| `Std.Function` | 14 | identity, composition both ways, repeated and bounded application |
| `Std.Show` | 12 | rendering any value, arrays, options, results, and padded tables |
| `Std.Io` | 26 | files, directories, standard input and output, path handling |
| `Std.Env` | 16 | arguments and flags, environment variables, stopping with a status |
| `Std.Time` | 40 | instants, durations, dates, times of day, formatting and parsing |
| `Std.Process` | 11 | running a program, its status and streams, availability |
| `Std.Bool` | 10 | the operators as functions, `select`, array folds |
| `Std.Tuple` | 10 | projection, exchange, per-side transformation, currying |

### On numbers

The numeric surface is **generic, bounded by traits**, not `Int`-only. `Std.Order` carries `Eq` and
`Ord`, `Std.Num` carries `Zero`, `One`, `Add`, `Sub`, `Mul`, and `Div`, and `Std.Bits` carries
`Bits` — each implemented across the integer family and, where it makes sense, both floating widths
and `Str`, `Char`, and `Bool`.

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

Nothing here is fixed to `Int`. `Range[N]` is generic over the integer family so a caller counting
in `UInt8` stays in `UInt8`, and `Items[T]`, `Indexed[T]`, and `Repeated[T]` carry the caller's own
element type. Fixing any of them to one type would have made the module useless for every other —
the same mistake [[ADR-0006]] was written to stop.

The functions over sequences are bounded by the trait rather than written per type, so `toArray`,
`count`, and `isEmpty` work for every sequence a program will ever declare:

```pudu
export fn toArray[S, T, Q: Sequence[S, T]](source: &Q) -> Array[T]
```

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

**A constant may not reach the world.** Compile-time folding runs the same evaluator with effects
denied and reports `E7009`. Compilation that depended on the world the compiler happened to be in
would not be compilation.

`Std.Time` separates an **`Instant`** from a **`Duration`** from a **`Date`**, each its own type.
That distinction is the one date handling gets wrong most often — a birthday is a date everywhere,
while a meeting is an instant — and a library that let them be added together would be inviting the
mistake rather than preventing it.

What is still blocked is the *foreign* interface — calling into a library this runtime does not
already contain. That is what `Std.Net`, `Std.Db`, and an HTTP client need, and it needs the
`foreign` capability from [[Unsafe Capabilities]] plus a decision about how a foreign type's
ownership is described.

### On HTTP

`Std.Http` and `Std.Http.Message` carry everything about the protocol that does not touch a socket:
building and inspecting requests, the full status and header vocabulary, cookies, basic and bearer
authorization, content negotiation with weights, form bodies, byte ranges, chunked framing, and
parsing or rendering a complete message.

**There is no client, and there will not be one until the foreign interface exists.** A `send` that
could not send would be worse than none: it would make a program compile and fail at run time for a
reason the type system could have carried. Everything up to the moment of sending is here and
testable without a network, which is the part a program spends most of its code on anyway.

Everything else in the tables above is designed and unwritten. `Std.Net`, `Std.Process`, `Std.Db`,
and an HTTP client are blocked on the foreign interface; the rest is library work waiting its turn.

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

## Deferred, with reasons

- **A package manager and third-party registry.** The standard library must be complete enough to be
  worth having before a registry is worth designing; shipping a registry first would make the
  standard library optional in practice, which is the outcome this design exists to avoid.
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
