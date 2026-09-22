# Standard library

The standard library ships with the compiler. Every module lives under `Std`, nothing is imported implicitly, and a program imports exactly what it uses. This page is a map; the [API reference](/modules) documents every public declaration.

## Core values

| Module | For |
| --- | --- |
| [Std.Option](/module/Std.Option) | working with values that may be absent |
| [Std.Result](/module/Std.Result) | working with work that may fail |
| [Std.Text](/module/Std.Text) | text: searching, splitting, numbers from text |
| [Std.Char](/module/Std.Char) | single characters |
| [Std.Math](/module/Std.Math) | numeric functions |
| [Std.Decimal](/module/Std.Decimal) | exact decimal arithmetic and rounding |
| [Std.Num](/module/Std.Num), [Std.Bits](/module/Std.Bits) | numeric traits, conversion through `BigInt`, and bitwise work |
| [Std.Random](/module/Std.Random) | seeded and clock-driven random numbers |
| [Std.Fmt](/module/Std.Fmt) | formatting values as text |

## Collections

| Module | For |
| --- | --- |
| [Std.List](/module/Std.List) | operations on arrays: sorting, grouping, searching |
| [Std.Map](/module/Std.Map) | ordered maps |
| [Std.Set](/module/Std.Set) | ordered sets |
| [Std.Iter](/module/Std.Iter) | sequences a `for` loop can walk |
| [Std.Deque](/module/Std.Deque), [Std.Heap](/module/Std.Heap) | queues and priority queues |

## Input, output, and the system

| Module | For |
| --- | --- |
| [Std.Io](/module/Std.Io) | standard input and output, files, streaming readers |
| [Std.Fs](/module/Std.Fs) | atomic writes, temporary files, permissions, metadata |
| [Std.Path](/module/Std.Path) | building and taking apart file paths |
| [Std.Env](/module/Std.Env) | arguments, environment variables, the clock |
| [Std.Process](/module/Std.Process) | starting other programs and talking to them |
| [Std.Time](/module/Std.Time) | dates, times, and durations |

## Data formats

| Module | For |
| --- | --- |
| [Std.Json](/module/Std.Json) | JSON documents and JSON Lines |
| [Std.Csv](/module/Std.Csv) | CSV, read one record at a time |
| [Std.Toml](/module/Std.Toml), [Std.Yaml](/module/Std.Yaml), [Std.Xml](/module/Std.Xml) | configuration and document formats |
| [Std.Regex](/module/Std.Regex) | regular expressions with a step limit |
| [Std.Bytes](/module/Std.Bytes) | binary data, hex, and base64 |

## Networking and the web

| Module | For |
| --- | --- |
| [Std.Http.Server](/module/Std.Http.Server) | an HTTP server with routing, limits, and graceful shutdown |
| [Std.Http.Client](/module/Std.Http.Client) | an HTTP client with verified TLS, redirects, and deadlines |
| [Std.Html](/module/Std.Html) | HTML built as values, escaped by construction |
| [Std.Url](/module/Std.Url) | parsing and building URLs |
| [Std.Net](/module/Std.Net), [Std.Tls](/module/Std.Tls) | sockets and verified TLS connections |

## Applications and databases

| Module | For |
| --- | --- |
| [Std.App](/module/Std.App) | an application as a value: settings, stages, health checks |
| [Std.App.Database](/module/Std.App.Database) | a database resource for SQLite or PostgreSQL |
| [Std.Db.Migrate](/module/Std.Db.Migrate) | numbered schema migrations that run once |
| [Std.Db.Store](/module/Std.Db.Store) | keeping a program's own values in a table |
| [Std.Crypto](/module/Std.Crypto) | hashes, message authentication, and encryption |

## Testing

| Module | For |
| --- | --- |
| [Std.Test](/module/Std.Test) | test suites that `pudu test` discovers and runs |
| [Std.Bench](/module/Std.Bench) | measuring how long code takes |

## Reading the reference

Every declaration in the [API reference](/modules) shows its signature and its documentation. You can also search by type shape from the home page: searching `Str -> UInt32` finds functions that take text and return a 32-bit number.
