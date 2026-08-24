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

Every language that deferred this decision paid for it twice. Haskell's `base` is small and its real
library surface — `text`, `bytestring`, `containers`, `time`, `aeson`, `http-client` — lives in
packages that a beginner must discover, choose between, and pin. The discovery cost is real: a
newcomer writing their first HTTP call chooses between four clients with different error models, and
the choice is invisible in their source. C++ made the opposite trade in the other direction, shipping
a standard library whose oldest corners now constrain what the newest ones can look like.

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

Each entry names its Haskell reference point, because that ecosystem has already discovered what the
right shape is, and the cost of rediscovering it is measured in years.

### Data

| Module | Reference | Provides |
|---|---|---|
| `Std.Text` | `text` | Unicode text, slicing, builders, case folding, encode/decode |
| `Std.Bytes` | `bytestring` | byte sequences, binary get/put, base64 and hex |
| `Std.List` | `Data.List` | the operations `Array[T]` does not already carry |
| `Std.Map` | `containers` | ordered maps, by comparison |
| `Std.Set` | `containers` | ordered sets |
| `Std.HashMap` | `unordered-containers` | hash maps, by `Hash` |
| `Std.Deque` | `containers` | double-ended queue |
| `Std.Math` | `base` | numerics, saturating and checked arithmetic, constants |
| `Std.Fmt` | `formatting` | typed formatting, no format-string interpretation at run time |
| `Std.Uuid` | `uuid` | v4 and v7 identifiers |

### Time

| Module | Reference | Provides |
|---|---|---|
| `Std.Time` | `time` | `Instant`, `Duration`, `Date`, `TimeOfDay`, `Zoned`, arithmetic |
| `Std.Time.Format` | `time` | RFC 3339 and strftime-shaped parsing and rendering |

`Std.Time` separates a **`Instant`** (a point on the monotonic or system clock) from a **`Date`** (a
civil calendar value with no instant until a zone is applied). The distinction is the single most
common source of correctness bugs in date handling, and a library that blurs it makes them
unreportable.

### Text processing

| Module | Reference | Provides |
|---|---|---|
| `Std.Text.Parse` | `megaparsec` | parser combinators with position-carrying errors |
| `Std.Json` | `aeson` | `Json` values, decoding to declared types, streaming encode |
| `Std.Csv` | `cassava` | row and record decoding |
| `Std.Toml` | `tomland` | configuration |

`Std.Text.Parse` is a combinator library rather than a regular-expression engine. A regex is a second
language embedded in a string, invisible to the type checker and to `pudu doc`; a combinator parser
is ordinary Pudu, so a malformed grammar is a compile error and a parser's type says what it
produces. A regex module remains open — see the deferred list.

### System

| Module | Reference | Provides |
|---|---|---|
| `Std.Io` | `base` | files, handles, streaming reads and writes |
| `Std.Path` | `filepath` | path construction and decomposition, platform-aware |
| `Std.Env` | `base` | arguments, environment, exit |
| `Std.Process` | `process` | subprocesses, pipes, exit status |
| `Std.Log` | `katip` | structured, levelled, context-carrying logging |

### Network

| Module | Reference | Provides |
|---|---|---|
| `Std.Http` | `http-client` | client: requests, responses, redirects, timeouts, pooling |
| `Std.Http.Server` | `warp` / `wai` | server: routing, handlers, middleware |
| `Std.Net` | `network` | addresses, TCP, UDP |
| `Std.Tls` | `tls` | transport security for the above |
| `Std.Url` | `network-uri` | parsing, building, percent-encoding |

### Concurrency

| Module | Reference | Provides |
|---|---|---|
| `Std.Concurrent` | `async` | task groups over the language's own `async with scope` |
| `Std.Channel` | `stm` | bounded and unbounded channels |
| `Std.Sync` | `stm` | mutex, semaphore, once, atomic cells |

`Std.Concurrent` is a thin layer over the structured scopes the language already has. It does not
introduce a second concurrency model: a task started through it is a child of the enclosing scope and
is joined by the same rules, so the library cannot leak a task the language would have caught.

### Correctness

| Module | Reference | Provides |
|---|---|---|
| `Std.Test` | `hspec` + `QuickCheck` | assertions, property generation, shrinking |
| `Std.Bench` | `criterion` | timing with statistics, not one stopwatch reading |
| `Std.Crypto` | `cryptonite` | hashes, HMAC, constant-time comparison, secure random |
| `Std.Db` | `postgresql-simple` | typed SQL, parameter binding, connection pooling |

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

- **Q:** Why not follow Haskell exactly and ship a minimal `base`, leaving the rest to packages?
  **A:** Because the discovery cost is paid by every newcomer and the fragmentation cost is paid by
  every reader. Haskell's split is historical rather than designed — `text` is not in `base` because
  `String` was there first — and copying the outcome without the history would be copying a
  constraint Pudu does not have. _Rejected:_ a minimal core plus a curated "platform" list, which is
  the same fragmentation with a blessing attached.
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
