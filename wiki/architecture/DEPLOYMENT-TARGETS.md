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

A runtime linked against the glibc of a current host records a version requirement — `GLIBC_2.34`
from a 24.04 build machine. AWS Lambda, which is what a Vercel function runs on, provides an older
one, as does every Alpine image. The loader refuses before any Pudu code runs, so nothing in the
program can report it and no diagnostic names the cause.

Linking glibc statically does not fix this and breaks something else: glibc resolves hostnames
through NSS modules it loads at run time, which a static link does not carry, so `Net.connect(host,
port)` fails for every name while an address still works. musl resolves names in the library itself.

So the runtime is linked against musl, built by `scripts/build-musl-runtime.sh`. The script pins its
toolchain image by digest and checks the finished binary does not need glibc, because a link that
quietly fell back produces a file that builds, passes a smoke test on the build machine, and fails on
the platform.

## Why the musl runtime is not fully static

A fully static binary cannot `dlopen`. `cbits/pudu_ffi.c` and `cbits/pudu_sqlite.c` load libraries
that way, so a fully static runtime would silently be one with no `Std.Foreign` and no SQLite driver.

The runtime is therefore dynamically linked against musl and statically against everything else —
libffi, zlib, ncurses, gmp. One file has to be present where it runs: musl's loader. That is what an
Alpine base supplies, and it is the whole difference between this and `FROM scratch`.

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
repeatedly and wants a request handler rather than a listener.

## What this does not yet do

- **It does not remove the JavaScript from the website's Vercel deployment.**
  `website/platform/vercel/index.js` reimplements ranked search in JavaScript, reading
  `website/data/api.json`. A musl runtime makes running Pudu on Lambda possible; moving that logic
  back into Pudu is separate work, and it is the larger part of what the adapter costs.
- **There is no Lambda custom-runtime mode.** Serving a Vercel function from the artefact with no
  Node launcher needs the runtime to poll the Lambda Runtime API. `website/src/Render.pudu` already
  handles one URL and exits, so the Pudu half of that shape exists.
- **There is no WebAssembly target.** It would mean compiling the evaluator through GHC's
  `wasm32-wasi` backend and shipping an interpreter into the edge runtime, and WASI has no listening
  sockets, so `Std.Http.Server` could not listen there at all. It would not reduce the start cost
  measured above, which is interpretation rather than process creation.

## Referenced by

[[architecture/APPLICATION-DEPLOYMENT]] · [[architecture/DELIVERY]] · [[architecture/WEBSITE]]
