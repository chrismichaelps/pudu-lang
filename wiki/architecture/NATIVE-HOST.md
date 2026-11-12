---
type: architecture
tags: [architecture, backend, native, host]
aliases: [Native Host Services]
---
# Native Host Services

What a program asks of the machine it runs on, and the forms that run later
than they are written, are native (#846).

| Area | Native surface |
| --- | --- |
| Tasks | `async fn`, async lambdas, an async entry, `.await` |
| Scopes | `async with scope { ... }`, children joined on its end, `return`, `break`, `continue` and a failure that leaves the function |
| Shared state | cells, mutexes, channels and threads behind their tokens |
| Process | clocks, sleeping, arguments, environment, directories and separators, `exit`, `secureRandomBytes` |
| Time | `formatTime` and `parseTime` over the percent specifiers of the fixed English locale |
| Signals | watching for the terminate and interrupt requests and reading whether one came |
| Sockets | stream endpoints: listening, accepting, connecting, bounded and unbounded sends and receives, peer and port, closing |
| TLS | verified connections through the system TLS library: connecting, upgrading a plain endpoint, sending, receiving a record, the proven name, closing |
| Compression | the gzip wrapper and the bare compressed stream, with levels and output limits |
| Child programs | starting with pipes, an environment and a directory; reading, writing, closing input, waiting, stopping; `runProgram` |
| Standard input | [[Native Host Input]] emits `readLine` directly and as a builtin value, with line, end and decoding outcomes |
| Files | whole-file reads and writes, directories, links, permissions, temporary files, atomic writes, open readers and writers |
| Math | the binary64 kernels |
| Lanes | the packed binary64 lane kernels |
| Constants | a constant folding leaves no product for, such as a table of functions, runs its initializer where it is read |

## Tasks

A task is the body it has not run yet. `Task[T, E]` forms to a function of
nothing answering `T`, or `Result[T, E]` when the task can fail, and an async
function answers the task of its body. Awaiting runs the body; a failure it
answers leaves the function as `?` would. An async entry is awaited as soon
as it is called. This is the interpreter's own order: nothing runs until an
await or the scope that owns the task is left.

## Scopes

[[Compiler Lower Scope]] and [[Native Host Scopes]] own the contract. A task
made while a scope is open is adopted by the innermost one; an awaited task
is let go; the rest are joined in the order they were made on every way out.

## Host calls

[[Compiler Lower Kernel Host]] and [[Compiler Lower Concurrent]] describe each
builtin; [[Native Host Runtime]] holds the C parts. A call that can fail
answers through [[Native Host State]], read once after the call. A held value
crosses as a box of one member. Threads take turns through one run gate, so
reference counts and frames stay single-threaded.

The generated C asks for `-lm` and `-pthread` after the source on platforms
that need them, and defines the POSIX feature macros before any header. A
program that compresses also asks for the system's zlib, and one that
secures a connection for the system's TLS library, each named only when the
program's C includes that header.

## Host families added after the first slice

[[Native Host Sockets]], [[Native Host TLS]], [[Native Host Child Programs]], [[Native Host
Compression]], [[Native Host Time]], [[Native Host Time Reading]] and [[Native
Host Signals]] each answer as the interpreter's own module does, including the
words of a refusal. Three things cannot be the same in both engines and are
kept out of every expectation:

| Difference | Why |
| --- | --- |
| A descriptor number inside a refusal (`<socket: N>`, `fd:N`) | each engine opens its own descriptors |
| The system's own reason in parentheses | one operating system words it differently from another |
| Which failure a write to a closed peer meets first | it depends on when the peer's reset arrives |
| The reason inside a refused handshake (`HandshakeFailed (...)`) | each engine's TLS library words its own verdict; the opening and the kind of failure are the same |
| The last bit of a library float kernel between machines | the machine's math library owns it; on one machine both engines call that library, and [[Native Host Math]] keeps a compiler from working the call out itself |

The native time reader checks the final rounded magnitude against its integer carrier.
Epoch seconds can produce any instant in the carrier. A larger instant or a
calendar numeric field whose magnitude exceeds fifteen decimal digits receives
the parse refusal.
The interpreter can return instants beyond that boundary.
A wait gives up the run gate, so a thread serving an endpoint and a thread
connecting to it take turns as channel waits do.

## Not native

Desktop windows, audio devices and the raster kernels keep their typed
E6001 refusals, as do foreign functions and foreign handles. Each needs a
device or a loaded library the generated C cannot name portably.

## Evidence

[[Backend Host Programs]] and [[Backend Service Programs]] carry the corpus
through the differential and counted-allocation harnesses.

## Referenced by

[[architecture/_MOC]] · [[Native Emission Coverage]]
