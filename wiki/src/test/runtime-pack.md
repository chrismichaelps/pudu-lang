---
type: module
path: "@root/test/runtime-pack.mjs"
fidelity: Active
domain: "[[Testing]]"
subsystem: "[[architecture/DELIVERY]]"
tags: [module, test, deployment]
aliases: [Runtime Pack Gate]
---

# Runtime Pack Gate

## Purpose and interface

`node test/runtime-pack.mjs <pudu>` serves a pack from a stand-in release (every asset reached
through a redirect) and builds against it. The served runtime is the compiler itself, which carries
the source digest any runtime built from its sources carries.

Checked: `linux-musl-x86_64` fetched, verified, attached, and run; `lambda-x86_64` written as
`bootstrap` with the loader and libraries beside it; the kept pack reused with no request; and
refusals for a tampered file, a file the manifest does not list, a runtime from other sources, a
file that is not gzip, an unpublished release, an unreachable server, plain HTTP to another machine,
an unknown target, and `--target` with `--runtime`. Builds run asynchronously because the server
answers from the gate's own process.

## Referenced by

[[Cli RuntimePack]] · [[Pudu CLI]]
