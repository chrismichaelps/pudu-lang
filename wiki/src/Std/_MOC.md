---
type: moc
tags: [moc, module, stdlib]
---

# Standard Library Module Map

- [[Std Html Build]] — persistent fluent nodes with checked destination migration, eager or deferred
  conditionals, and exact rendering delegated to `Std.Html`.
- [[Std Html SSR]] — reusable flat or nested typed shells, text or retained-byte plans, exact
  lengths, output budgets, and pull-based bounded incremental delivery.
- [[Std Html Buffer]] — byte templates with permissive or checked exact-size assembly, opt-in compact
  static blocks, typed failures, and explicitly bounded application-output coalescing.
- [[Std Html Stream]] — prepared safe heads, typed progressive suspense output, deferred producers,
  and retained unchecked compatibility helpers.
- [[Std Http Server Stream]] — chunked HTTP/1.1 transport over raw sockets with early flush.
- [[Std Http Server Resilience]] — network-aware adaptive delivery, 2G/Save-Data profiles, and 14KB initcwnd budget.
- [[Std Http Server Security]] — defense-in-depth security headers, CSP nonces, and constant-time token verification.
- [[Std Html Media]] — network-adaptive responsive image and media delivery with low-bandwidth budgeting.
- [[Std App IsrCache]] — zero-copy thread-safe byte cache with tag-based invalidation for ISR.
- [[Std Ui Island]] — isolated island elements, client micro-runtime, and zero-JS form fallback.

- [[Std Html Compose]] — fluent persistent content composition with eager or deferred conditionals.

- [[Std BitSet]] — sparse UInt64 membership and block-wise set algebra.
- [[Std BitVector]] — dense 64-bit word packed bit-vector, SIMD bitwise algebra, and hardware scans.
- [[Std Buffer]] — contiguous byte buffer for unboxed scalar manipulation.
- [[Std FlatMap]] — ultra-fast flat hash table with 1-byte control metadata.
- [[Std Column]] — vectorized columnar database storage and SIMD aggregations.

- [[Std Byte Cursor]] — checked binary reads retaining absolute byte positions.
- [[Std Source Buffer]] — LF line indexing and explicit byte-coordinate locations.
- [[Std Symbol Interner]] — persistent, session-local spelling IDs.
- [[Std Text]] — total character-oriented search, trim, pad, split, fold, and comparison helpers.
- [[Std Text Builder]] — persistent fragments with explicit final text materialization.

- [[Std Random]] — deterministic generators and OS-backed secure bytes.
- [[Std Order]] — equality, ordering, and hashing contracts.
- [[Std Bits]] — fixed-width integer bit operations and generic width-aware helpers.
- [[Std HashMap]] — persistent indexed lookup with deterministic insertion order.
- [[Std Bytes]] — compact byte sequences, binary reads/writes, and text codecs.
- [[Std Compress Gzip]] — RFC 1952 GZIP compression, multi-block DEFLATE streaming, IEEE 802.3 CRC-32, and HTTP middleware.
- [[Std Csv]] — quoted separated-row and header-table parsing/rendering.
- [[Std Toml]] — TOML 1.0 configuration with exact numeric/time spellings.
- [[Std Yaml]] — the configuration subset of YAML, refusing anchors, tags, and merge keys, with bounded nesting.
- [[Std Glob]] — path patterns with segment-bound `*`, crossing `**`, sets, and a linear matcher.
- [[Std Regex]] — compiled regular expressions with a step bound and bounded group nesting.
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
- [[Std Tls]] — connections whose contents only the two ends can read.
- [[Std Db Protocol]] — PostgreSQL v3 wire framing and fields.
- [[Std Db Schema]] — columns as names the compiler knows, so an editor offers them.
- [[Std Db Query Shape]] — putting a statement together out of more than one table.
- [[Std Db Store]] — a program's own values kept and read back, with nothing left unread.
- [[Std Db Repository]] — rows as the program's own values, naming the column when one is wrong.
- [[Std Db Query]] — statements in which a value cannot become part of what runs.
- [[Std Db Migrate]] — bringing a schema to what the program expects, once and never half way.
- [[Std Db Session]] — becoming a connection, and one message across it at a time.
- [[Std Db]] — queries, rows, transactions, and pools over a session.
- [[Std App]] — the program as a value: what starts it, and what stops it.
- [[Std Html]] — a page as a value, with typed eager or deferred conditional construction.
- [[Std Html Bounded]] — iterative HTML rendering that stops at an exact UTF-8 output budget.
- [[Std Validate]] — saying what is wrong with everything that is wrong, once.
- [[Std Ui Live]] — a screen held on the server, sending what changed.
- [[Std Ui Theme]] — color roles, spacing, type scale, light and dark, and contrast audits.
- [[Std Ui Motion]] — transitions with easing curves and springs, retargetable mid-flight.
- [[Std Ui History]] — undo and redo over whole states.
- [[Std Ui Virtual]] — the rows of a long list a viewport shows.
- [[Std Ui Keymap]] — shortcut chords to commands, per platform, with menu labels.
- [[Std Ui Controls]] — accessible buttons, toggles, steppers, pickers, progress, and fields, with their updates.
- [[Std Ui Navigation]] — page stacks, tabs, split views, sheets, alerts, and confirmations.
- [[Std Ui Preferences]] — settings saved atomically in the platform's per-user directory.
- [[Std Ui Menu]] — menu bars as data, drawn with shortcuts and checked against the keymap.
- [[Std Ui Gesture]] — taps, long presses, and drags recognized from pointer phases.
- [[Std Ui Clipboard]] — the system clipboard's text, read and replaced.
- [[Std Ui Selection]] — single, range, and toggle selection over list rows, keyboard-driven.
- [[Std Ui Grid]] — cells in equal flexible columns, with row and column arithmetic.
- [[Std Ui Draw]] — exact-pixel strokes, polylines, and outlines over the canvas.
- [[Std Ui]] — screens as functions from state to view, and the difference between two.
- [[Std Ui Canvas]] — bounded Pudu-native RGBA software rendering for application UI.
- [[Std Ui Layout]] — declarative views placed in two passes, with accessibility and damage.
- [[Std Ui Screen]] — state, view, and update driven by routed input with damage-only repaint.
- [[Std Ui Text]] — an original bitmap face: measuring, wrapping, and drawing into the canvas.
- [[Std Ui Desktop]] — bounded plans and explicit sessions for real desktop window presentation.
- [[Std Ui Accessible]] — the accessibility snapshot a window is given, and the platform's report of it.
- [[Std Audio]] — exact 16-bit PCM, rational time, Q15 gain, saturating mix, and bounded WAV.
- [[Std Audio Graph]] — a stateless pull-model render graph over bounded, slice-independent renders.
- [[Std Audio Device]] — bounded PCM playback plans with exact completion and typed target failures.
- [[Std Video]] — exact fractional rates and timestamps, ordered picture tracks, and audio alignment.
- [[Std Fs]] — atomic replacement, claimed temporary names, permissions, and link-aware containment.
- [[Std Crypto]] — named digest families, keyed digests, constant-time comparison, and sealing.
- [[Std Mail]] — a message a program sends, which cannot carry more than it says.
- [[Std Mail Smtp]] — native RFC 5321 client transport over streaming TCP with AUTH LOGIN/PLAIN and multi-line reply parsing.
- [[Std App Cache]] — keeping an answer for a while, and saying when it is old.
- [[Std App Locale]] — saying the same thing in the language the reader asked for.
- [[Std App Work]] — the work a service does when nobody asked.
- [[Std App Trace]] — following one piece of work across every service that touched it.
- [[Std App Session]] — remembering who somebody is, under a name nobody else may choose.
- [[Std App Password]] — a password kept in a form that proves it without holding it.
- [[Std App Secret]] — secrets protected from unintended disclosure with explicit redaction.
- [[Std App Flag]] — value-based feature flags with percentage and allowlist targeting.
- [[Std App Problem]] — RFC 9457 problem bodies, validation reports as 422, and a uniform failure step.
- [[Std App Page]] — keyset cursor pagination with bounded sizes and `Link` headers.
- [[Std App Idempotency]] — replayed answers for repeated `Idempotency-Key` requests.
- [[Std App Events]] — ordered in-process publish/subscribe and an outbox drained after commit.
- [[Std App OpenApi]] — OpenAPI 3.1 descriptions checked against the router that serves them.
- [[Std App Audit]] — tamper-evident structured security audit logging with SHA-256 hash chaining.
- [[Std App Access]] — a route that decided nothing cannot be written.
- [[Std App Tenant]] — multi-tenant isolation, noisy-neighbor mitigation, and quota admission control.
- [[Std App Totp]] — RFC 6238 time-based one-time passwords for multi-factor authentication.
- [[Std App Jwt]] — RFC 7519 JSON Web Tokens with HS256 HMAC signing and constant-time claims validation.
- [[Std App Metrics]] — what a program reports about itself, with bounded label cardinality.
- [[Std App Bind]] — what a request carries, as a typed value or a refusal.
- [[Std App Health]] — restarting and receiving traffic, kept apart by the types.
- [[Std App Config]] — where a setting comes from when four places could supply it.
- [[Std Http Client]] — sending a request somewhere and reading what comes back.
- [[Std Http Multipart]] — reading a form that carried files, without letting the sender choose where they go.
- [[Std Http Safe]] — the judgements a server makes before it believes a request.
- [[Std Http Server]] — reading requests off connections and answering them.
- [[Std Http Server Lambda]] — driving an invocation runtime directly from Pudu.
- [[Std Http Server Guard]] — the steps that make a service safe before anyone asks.
- [[Std Http Server Socket]] — a connection that stays open, and who may open one.
- [[Std Http Server Route]] — which handler answers a request, and what it is given.
- [[Std Http Server Reply]] — the answers a handler gives.
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
- [[Std Cron]] — five-field schedule expressions, matching, and the next firing minute in UTC.
- [[Std Stats]] — descriptive statistics, percentiles, correlation, histograms, and a streaming accumulator.
- [[Std Dotenv]] — environment files read into ordered entries, expanded, and rendered back.
- [[Std Term]] — terminal colour and styling sequences, stripping, and cursor control.
- [[Std Json]] — deterministic JSON parsing, rendering, lookup, and updates.
- [[Std Xml]] — XML elements, attributes, text, and CDATA with bounded nesting and refused DTDs.
- [[Std Url]] — pure URL parsing, rendering, queries, and percent encoding.
- [[Std Math]] — generic total numeric algorithms.
- [[Std Math Float]] — high-performance IEEE-754 trigonometry, logarithms, exponentials, hyperbolic functions, and constants.
- [[Std IntMap]] — high-performance bitwise Patricia Trie integer map inspired by Haskell Data.IntMap.
- [[Std IntSet]] — high-performance bitwise Patricia Trie integer set inspired by Haskell Data.IntSet.
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
- [[Std Archive Tar]] — POSIX USTAR archive streaming encoding, decoding, and entry extraction.
- [[Std BloomFilter]] — probabilistic set membership with zero false negatives and double hashing.
- [[Std Mime]] — MIME Media Type parsing, extension registry, and HTTP Accept negotiation.
- [[Std Diff]] — Myers O(ND) sequence difference, Unified Diff format, and Levenshtein metric.
- [[Std FenwickTree]] — Binary Indexed Tree for prefix sums, point updates, and binary lifting search.
- [[Std RingBuffer]] — bounded power-of-two circular FIFO buffer with branchless bitmask wrapping.
- [[Std Varint]] — variable-length integer encoding (ULEB128 and signed ZigZag SLEB128).
- [[Std DisjointSet]] — flat-array Union-Find with iterative path halving and union-by-rank.
- [[Std Murmur3]] — hardware-oriented non-cryptographic hash function with word rotations and bit avalanche.
- [[Std RateLimiter]] — fixed-point integer token bucket traffic shaper with burst allowance.
- [[Std Hex]] — low-level Base16 hexadecimal encoder, decoder, and validator.
- [[Std Adler32]] — RFC 1950 Adler-32 unrolled checksum and rolling stream hash.
- [[Std RadixSort]] — linear-time O(N) hardware radix sort for 64-bit integers.
- [[Std ByteOrder]] — hardware byte-swapping and big/little-endian binary codecs.
- [[Std SipHash]] — keyed SipHash-2-4 hash function for HashDoS collision protection.
- [[Std IntervalTree]] — augmented 1D interval tree for stabbing and overlap queries.

- [[Std Db ConnectionString]] — explicit PostgreSQL URI settings and socket/pool opening.
- [[Std App Database]] — application-owned pools and bound queries.

- [[Std Db Driver]] — backend-neutral clients, typed values and explicit driver selection.
- [[Std Db Postgres]] — PostgreSQL adapter for the shared driver contract.

- [[Std Db Sqlite]] — embedded SQLite prepared statements through the shared driver contract.

- [[Std Db Row]] — typed backend-neutral result access and cardinality-aware mapping.

## Referenced by

[[src/_MOC]] · [[architecture/STDLIB]]

- [[Std Net Bounded Read]] — shared-deadline delimiter and exact reads.


## TLS and binary response integration

[[Std Mail Smtp]] requires explicit destination and EHLO identity; verified implicit TLS and required
STARTTLS use [[Std Tls]]. [[Std Compress Gzip]] delegates to [[Eval Compress]] and emits binary
[[Std Http]] responses through [[Std Http Message]] and [[Std Http Server]].
