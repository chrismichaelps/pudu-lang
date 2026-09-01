---
type: moc
tags: [moc, module, stdlib]
---

# Standard Library Module Map

- [[Std Random]] — deterministic generators and OS-backed secure bytes.
- [[Std Order]] — equality, ordering, and hashing contracts.
- [[Std HashMap]] — persistent indexed lookup with deterministic insertion order.
- [[Std Bytes]] — compact byte sequences, binary reads/writes, and text codecs.
- [[Std Csv]] — quoted separated-row and header-table parsing/rendering.
- [[Std Toml]] — TOML 1.0 configuration with exact numeric/time spellings.
- [[Std Toml Read]] — turning configuration text into that model.
- [[Std Toml Scan]] — the lexical layer beneath the reader.
- [[Std Path]] — host-aware lexical path construction and decomposition.
- [[Std Uuid]] — byte-backed deterministic v4/v7 identifiers.
- [[Std Bench]] — repeated measurement and distribution summaries.
- [[Std Time Format]] — civil arithmetic and RFC/protocol time codecs.
- [[Std Time Format Civil]] — proleptic Gregorian day arithmetic.
- [[Std Concurrent]] — joinable host-thread work.
- [[Std Channel]] — bounded typed queues with closure.
- [[Std Sync]] — runtime mutexes and atomic cells.
- [[Std Net]] — streaming-first TCP listeners and connections.
- [[Std Db Protocol]] — PostgreSQL v3 wire framing and fields.
- [[Std Db]] — PostgreSQL authentication, binding, transactions, and pools.
- [[Std Http Server]] — deterministic routing, middleware, and bounded serving.
- [[Std Http]] — pure HTTP protocol values and transformations.
- [[Std Http Message]] — HTTP message parsing, rendering, length validation, and chunk decoding.
- [[Std Result]] — recoverable-result combinators and collection traversal.
- [[Std Iter]] — open sequence protocol, lazy adapters, and terminals.
- [[Std Option]] — optional-value combinators, conversions, and collection helpers.
- [[Std Text Parse]] — positioned parser combinators and numeric/text readers.
- [[Std Io]] — portable console, filesystem, directory, and path operations.
- [[Std Out]] — a printer as a value, carrying how output is written.
- [[Std Fmt]] — a shaping spec as a value, carrying how one is shaped before that.
- [[Std Test]] — checks and suites as values, and a report that says what failed.
- [[Std Test Property]] — generated values with shrinking, seeded so a failure repeats.
- [[Std Log]] — a logger as a value, carrying a level, a name, fields, and a format.
- [[Std Process]] — subprocess results and convenience projections.
- [[Std Time]] — instants, durations, calendar conversion, and clocks.
- [[Std Json]] — deterministic JSON parsing, rendering, lookup, and updates.
- [[Std Url]] — pure URL parsing, rendering, queries, and percent encoding.
- [[Std Math]] — generic total numeric algorithms.
- [[Std Tree]] — a value with trees beneath it, with orders, paths, and pruning.
- [[Std Mappable]] — a trait over the container, so one definition serves several.
- [[Std SortedMap]] — a map ordered by the caller's comparison, with neighbour and range queries.
- [[Std LinkedMap]] — a map that iterates in the order its keys were first inserted.
- [[Std EnumMap]] — a total map over a fixed key domain.
- [[Std BiMap]] — a pairing readable from either side, kept a bijection.
- [[Std MultiMap]] — many values under one key, with the empty-key bookkeeping done.
- [[Std MultiKeyMap]] — a two-part key with lookup by the whole key or either part.
- [[Std LruCache]] — a bounded map that discards what has gone longest unused.
- [[Std PrefixTrie]] — text keys held by their characters, searchable by prefix.

## Referenced by

[[src/_MOC]] · [[architecture/STDLIB]]
