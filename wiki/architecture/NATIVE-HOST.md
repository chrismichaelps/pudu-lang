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
that need them, and defines the POSIX feature macros before any header.

## Not native

Sockets and TLS, child processes, compression, time formatting, signals,
desktop windows, audio devices and the raster kernels keep their typed E6001
refusals, as do foreign functions, foreign handles and `unsafe` raw access.

## Evidence

[[Backend Host Programs]] carries the corpus through the differential and
counted-allocation harnesses.

## Referenced by

[[architecture/_MOC]] · [[Native Emission Coverage]]
