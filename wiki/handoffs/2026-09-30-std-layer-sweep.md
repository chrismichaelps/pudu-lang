---
type: handoff
tags: [handoff, stdlib, runtime, performance]
---

# Std Sweep by Dependency Layer — Issues #395–#422

## Scope and role transitions

Architect → Standard Library and Runtime Engineer: find defects in `lib/Std` not already reported,
report each as an issue, and repair it, working from the import graph's lowest layers upward so a
fault found once is fixed for every module above it. The user authorizes direct commits to `dev`,
issue closure, and no pull request. Work ran in its own worktree from fresh `dev`.

## Method

The import graph was layered: a module's layer is one more than the deepest module it imports.
Every module in every layer went through three tree-wide checks:

- the checker with `W3004`, which reports a value dropped by a line starting with `-` and found
  the one such fault in Std;
- a search for text or bytes rebuilt by concatenation inside a loop, the shape behind #404, #411,
  #412, and #413;
- a search for array membership tests inside a loop, the shape behind #410 and #414.

Modules that parse external text, hold large collections, or compute published algorithms were then
probed directly: against reference vectors (zlib, `hashlib`, RFC 6238), against the builtin `Map`
and `Set` over thousands of random operations, over real sockets, or with hostile inputs.

## Coverage

Layer is the module's depth in the import graph. "Swept" means the three tree-wide checks above
and no targeted probe.

| Layer | Module | Examination |
|---|---|---|
| 0 | Adler32 | zlib vectors, roll, combine |
| 0 | App.Flag | swept |
| 0 | App.Stage | swept |
| 0 | Base32 | RFC 4648 vectors and refusals |
| 0 | BiMap | swept |
| 0 | BitSet | differential |
| 0 | Bits | probes |
| 0 | Bool | swept |
| 0 | Buffer | swept |
| 0 | ByteOrder | bounds and swaps |
| 0 | Bytes.Cursor | swept |
| 0 | Char | swept |
| 0 | Checksum | CRC-32, FNV-1a vectors |
| 0 | Crypto | SHA-1/256/512, SHA3, HMAC vectors |
| 0 | Db.Driver | swept |
| 0 | Decimal | parse/round/divide (#400) |
| 0 | Env | swept |
| 0 | FlatMap | differential |
| 0 | Function | swept |
| 0 | Intern | swept |
| 0 | IntervalTree | probes, balancing (#406) |
| 0 | Ip | parser read |
| 0 | Map | swept |
| 0 | Math.Float | swept |
| 0 | Mime | swept |
| 0 | MultiKeyMap | swept |
| 0 | Num | swept |
| 0 | Option | swept |
| 0 | Order | swept |
| 0 | PrefixTrie | probes, counts (#409) |
| 0 | RateLimiter | swept |
| 0 | Result | swept |
| 0 | Semver | precedence rules |
| 0 | Set | swept |
| 0 | Show | rendering probes |
| 0 | Signal | swept |
| 0 | Text | empty needle (#395), padding, words |
| 0 | Text.Builder | swept |
| 0 | Text.Source | swept |
| 0 | Time | toSeconds (#419) |
| 0 | Time.Format.Civil | swept |
| 0 | Time.Format.Header | new (#399) |
| 0 | Tuple | swept |
| 0 | Ui.Clipboard | swept |
| 0 | Ui.History | swept |
| 0 | Ui.Keymap | swept |
| 0 | Ui.Virtual | swept |
| 0 | Varint | overflow (#401) |
| 1 | App.Health | swept |
| 1 | App.Locale | swept |
| 1 | App.Secret | swept |
| 1 | Args | parsing probes |
| 1 | Bytes | swept |
| 1 | Channel | swept |
| 1 | Column | swept |
| 1 | Cron | parse and next() probes |
| 1 | Db.Repository | swept |
| 1 | Db.Row | swept |
| 1 | Db.Schema | swept |
| 1 | Dotenv | quoting (#402) |
| 1 | Html | control-character bypass (#421) |
| 1 | Human | bytes/duration/ordinal/relative probes |
| 1 | Iter | swept |
| 1 | LinkedMap | rewrite (#405) |
| 1 | List | sort (#408), sets (#410) |
| 1 | Mail | address grammar (#417) |
| 1 | Math | swept |
| 1 | Path | normalize/relative/extension probes |
| 1 | Random | bounds and sampling probes |
| 1 | Regex | syntax and replacement probes |
| 1 | Sync | swept |
| 1 | Term | swept |
| 1 | Text.Parse | swept |
| 1 | Time.Format | strict RFC 3339/HTTP-date (#396, #398, #399) |
| 1 | Toml | swept |
| 1 | Ui.Motion | swept |
| 1 | Url | encoding round trips, plus in paths (#420) |
| 1 | Validate | membership (#414) |
| 1 | Xml | well-formedness probes (#416) |
| 1 | Yaml.Quoted | swept |
| 2 | App.Audit | swept |
| 2 | App.IsrCache | swept |
| 2 | App.Metrics | swept |
| 2 | App.Password | swept |
| 2 | App.Totp | RFC 6238 SHA-256 vectors, lengths (#418) |
| 2 | App.Trace | swept |
| 2 | App.Work | swept |
| 2 | Archive.Tar | swept |
| 2 | Audio | swept |
| 2 | Bench | swept |
| 2 | BitVector | probes |
| 2 | BloomFilter | no false negatives |
| 2 | Concurrent | swept |
| 2 | Db.Protocol | bind building (#413) |
| 2 | Db.Query | swept |
| 2 | Db.Sqlite | swept |
| 2 | Deque | probes |
| 2 | Diff | Levenshtein |
| 2 | DisjointSet | unions |
| 2 | EnumMap | swept |
| 2 | FenwickTree | probes |
| 2 | Fmt | number and truncation probes |
| 2 | Glob | pattern probes |
| 2 | HashMap | differential |
| 2 | Heap | probes |
| 2 | Hex | decoder read |
| 2 | Html.Bounded | swept |
| 2 | Html.Buffer | swept |
| 2 | Html.Build | escaping and checked destinations |
| 2 | Html.Stream | swept |
| 2 | Http | swept |
| 2 | Http.Multipart | membership (#414) |
| 2 | Http.Server.Resilience | swept |
| 2 | Http.Server.Security | swept |
| 2 | IntMap | differential |
| 2 | IntSet | differential |
| 2 | Io | swept |
| 2 | LruCache | probes, scaling (#405) |
| 2 | MultiMap | swept |
| 2 | Murmur3 | published vectors |
| 2 | Net | rewritten reads, socket scaling and split-marker test (#411) |
| 2 | NonEmpty | swept |
| 2 | Out | swept |
| 2 | Pem | armor refusals |
| 2 | RadixSort | swept |
| 2 | RingBuffer | probes |
| 2 | SipHash | reference vectors |
| 2 | SortedMap | differential |
| 2 | Stats | percentile/variance probes |
| 2 | Toml.Scan | swept |
| 2 | Tree | swept |
| 2 | Ui | swept |
| 2 | Ui.Canvas | swept |
| 2 | Ui.Island | swept |
| 2 | Uuid | parse, v7 layout and order |
| 2 | Yaml.Block | swept |
| 3 | App.Cache | swept |
| 3 | App.Session | swept |
| 3 | Audio.Device | swept |
| 3 | Audio.Graph | swept |
| 3 | Concurrent.Cancel | swept |
| 3 | Concurrent.Coordinate | swept |
| 3 | Csv | delimiters (#403), tables |
| 3 | Db.Query.Shape | swept |
| 3 | Db.Session | swept |
| 3 | Fs | swept |
| 3 | Graph | roots (#407) |
| 3 | Html.Media | swept |
| 3 | Html.Ssr | swept |
| 3 | Http.Message | request parsing and framing |
| 3 | Http.Safe | framing read |
| 3 | Json | path, withField, duplicate keys |
| 3 | Log | swept |
| 3 | Mappable | swept |
| 3 | Net.Read | same (#411) |
| 3 | Process | swept |
| 3 | Site | swept |
| 3 | Test | swept |
| 3 | Tls | limit and scaling (#412) |
| 3 | Toml.Read | swept |
| 3 | Ui.Gesture | swept |
| 3 | Ui.Text | swept |
| 3 | Ui.Theme | swept |
| 3 | Video | swept |
| 3 | Yaml | swept |
| 4 | App.Config | swept |
| 4 | App.Events | swept |
| 4 | App.Jwt | swept |
| 4 | App.Page | swept |
| 4 | Concurrent.Future | swept |
| 4 | Concurrent.Retry | swept |
| 4 | Db | swept |
| 4 | Html.Compose | swept |
| 4 | Http.Client | response framing read |
| 4 | Http.Server.Reply | swept |
| 4 | Http.Server.Stream | swept |
| 4 | Mail.Smtp | reply buffer read |
| 4 | Test.Property | swept |
| 4 | Ui.Draw | swept |
| 4 | Ui.Layout | swept |
| 4 | Ui.Live | swept |
| 4 | Ui.Preferences | swept |
| 5 | App.Otlp | swept |
| 5 | Concurrent.Pool | swept |
| 5 | Concurrent.Scope | membership (#414) |
| 5 | Db.ConnectionString | swept |
| 5 | Db.Migrate | swept |
| 5 | Db.Store | membership (#414) |
| 5 | Http.Retry | swept |
| 5 | Http.Server.Lambda | swept |
| 5 | Http.Server.Route | hostile paths, parameter decoding (#422) |
| 5 | Ui.Accessible | membership (#414) |
| 5 | Ui.Grid | swept |
| 5 | Ui.Screen | swept |
| 6 | App.Access | swept |
| 6 | App.Bind | swept |
| 6 | App.Problem | swept |
| 6 | App.Tenant | swept |
| 6 | Compress.Gzip | swept |
| 6 | Db.Postgres | swept |
| 6 | Http.Server | body framing read |
| 6 | Http.Server.Guard | swept |
| 6 | Http.Server.Socket | swept |
| 6 | Ui.Controls | swept |
| 6 | Ui.Selection | swept |
| 7 | App.Database | swept |
| 7 | App.Idempotency | swept |
| 7 | App.OpenApi | swept |
| 7 | Archive.Zip | swept |
| 7 | Ui.Menu | swept |
| 7 | Ui.Navigation | swept |
| 8 | App | swept |
| 8 | Ui.Desktop | swept |
## Left as documented

`Std.Xml` keeps unknown entities, drops numeric references that name no character, and does not
read past the root element, as its native reader documents. `Std.Json` keeps repeated object keys
and `field` answers the first. `Text.words` splits on spaces only. `Json.path` follows object keys
only. `Http.Message.parseRequest` leaves body framing to `Http.Safe.framing`, which refuses
conflicting lengths and a message framed both ways.

## Exact next action

Give `Html.Ssr` and `Http.Server.Guard` targeted probes with hostile input, the request-facing
modules still marked "swept" above.

## Referenced by

[[handoffs/_MOC]] · [[CHANGELOG]]
