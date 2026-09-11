---
type: architecture
tags: [deployment, build, bundle, musl, serverless]
aliases: [Deployment Targets]
---
# Deployment Targets

## What a built artefact is

`pudu build` writes one file: a copy of the Pudu runtime with the program's modules appended and a
trailer saying where they start. Running it finds its own modules and runs them. Nothing else has to
be installed.

This is not native code generation, and the distinction decides everything below. The program is
still compiled and interpreted every time it starts. What a bundle removes is the installation, not
the interpretation. So there is no per-architecture code generator to target: where an artefact can
run is decided entirely by **how its runtime was linked**, and by what the runtime needs from the
filesystem once it starts.

## Why a runtime built on a current Linux does not run on Lambda

A runtime linked against the glibc of its build host records that host's symbol-version requirements.
AWS Lambda and Alpine do not promise that exact libc contract. The loader can refuse before any Pudu
code runs, so nothing in the program can report it and no diagnostic names the cause.

Linking glibc statically does not fix this and breaks something else: glibc resolves hostnames
through NSS modules it loads at run time, which a static link does not carry, so `Net.connect(host,
port)` fails for every name while an address still works. musl resolves names in the library itself.

So the runtime is linked against musl, built by `scripts/build-musl-runtime.sh`. The script pins its
toolchain image by digest and checks the finished binary does not need glibc, because a link that
quietly fell back produces a file that builds, passes a smoke test on the build machine, and fails on
the platform. CI exercises the Lambda package on Vercel's Amazon Linux 2023 target.

## Why the musl runtime is not fully static

A fully static binary cannot `dlopen`. `cbits/pudu_ffi.c` and `cbits/pudu_sqlite.c` load libraries
that way, so a fully static runtime would silently be one with no `Std.Foreign` and no SQLite driver.

The runtime is therefore dynamically linked against musl and the C libraries used by libffi, zlib,
ncurses, and gmp. A normal Alpine host supplies them. The Lambda package carries the matching loader
and shared objects beside its Pudu function, and the Lambda runtime searches its own directory for
those files. This preserves dynamic loading without depending on the host's glibc libraries.

## Building for a platform from a machine that is not it

`pudu build --runtime <path>` attaches the program to a named runtime instead of to the compiler
doing the building. That is what lets a developer on macOS produce a Linux artefact:

```bash
scripts/build-musl-runtime.sh -o dist/pudu-musl-x86_64
pudu build src/Main.pudu -o dist/server --runtime dist/pudu-musl-x86_64
```

Two things about it are worth knowing.

**The runtime must be the same version of Pudu as the compiler.** A bundle carries source, and a
runtime of another version would check it by different rules than the ones it was just admitted
under. Nothing in the build can see the version of a binary it cannot run, so that agreement is the
caller's to keep. Build both from one checkout, or record which release a downloaded runtime came
from.

**A runtime that already carries a program is replaced, not appended to.** The trailer is read from
the end of the file, so appending to a built artefact would work and would keep the previous
program's bytes for ever. Building twice would double the file. So a bundle already attached is
removed first, and building onto a bare runtime and onto a freshly built artefact answer the same
bytes.

## What a bundle needs where it runs

A bundle writes its modules — the standard library among them — to a temporary directory each time it
starts, and compiles them. Three consequences:

- **A writable temporary directory is required.** A read-only root filesystem stops the program
  before it runs. Cloud Run and Lambda both provide a writable `/tmp`; a hardened Kubernetes pod
  needs an `emptyDir` mounted at it. `scratch` has no `/tmp` and no shell to create one.
- **Certificate authorities are required for `Std.Tls`**, which verifies against the host trust
  store. Without them every HTTPS connection fails to verify, which reads as a broken server.
- **Starting costs what interpreting the program costs.** Measured on an Apple M-series host with an
  `-O2` runtime: 145 ms for a program importing nothing, 413 ms for one importing five library
  modules (eleven modules carried). A daemon pays that once. A serverless function pays it on every
  cold start.

That last figure is the argument for the platforms that run a daemon. Cloud Run, Fly.io, Render,
Railway and AWS App Runner all run a compiled daemon directly, and `deploy/Dockerfile` is what they
need. Vercel's serverless model freezes a process between requests, so it pays the start cost
repeatedly and wants a request handler rather than a listener — which is what the next section is.

## Serving a platform that invokes rather than connects

A serverless platform does not connect to a service. It starts a process, hands it one request at a
time, and freezes it in between, so a program written as a listener has nothing to listen to. The
usual answer is a wrapper in the platform's own language — which then holds a second copy of whatever
it took to answer the request, and that copy can disagree with the first.

`Std.Http.Server.Lambda` is the other answer: the program asks the platform for work rather than
waiting to be connected to, over the interface AWS Lambda defines and every platform built on it
speaks. What it serves is an ordinary handler, so a service is written once and `Main.pudu`,
`Function.pudu` and `Render.pudu` all serve the same routes.

The interface is a value — its address and its protocol version are both settable — rather than read
from the environment at each call. That is what lets a program reach one this module did not assume,
and what lets the loop be pointed at a server a fixture starts, which is how it is tested at all.
`fromEnvironment` reads the address a platform announces; a program that also runs as a listener asks
for it and decides, so one build runs in both places.

Vercel's Build Output API names this runtime `provided.al2023` and starts the artefact as `bootstrap`.
`website/scripts/build-vercel.sh` emits that.

## What this does not yet do

- **There is no WebAssembly target.** It would mean compiling the evaluator through GHC's
  `wasm32-wasi` backend and shipping an interpreter into the edge runtime, and WASI has no listening
  sockets, so `Std.Http.Server` could not listen there at all. It would not reduce the start cost
  measured above, which is interpretation rather than process creation.

## Referenced by

[[architecture/APPLICATION-DEPLOYMENT]] · [[architecture/DELIVERY]] · [[architecture/WEBSITE]]
