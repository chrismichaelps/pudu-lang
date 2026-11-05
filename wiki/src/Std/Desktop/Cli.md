---
type: module
path: "@root/lib/Std/Desktop/Cli.pudu"
fidelity: Active
domain: "[[Pudu Program]]"
subsystem: "[[Standard Library]]"
grammar: "[[grammar/pudu]]"
tags: [module, stdlib, desktop, tooling]
aliases: [Std Desktop Cli]
---

# Std Desktop Cli

## Purpose and interface

The program behind `pudu desktop`. Commands, dispatched through a const factory table:
`init <dir>`, `dev`, `types [--out path]`, `build`, `bundle [--executable path --arch name]`,
`keygen [--out path]`, `sign <file> [--key path]`, `delta <old> <new> <patch>` and
`manifest --artifact path --url url [--patch path --patch-url url --from version] [--notes text]`.
Every command but `init`, `keygen`, `sign` and `delta` reads `pudu-desktop.toml` (or `--config`).

## Semantics

- `dev` runs `pudu run --watch <entry>` with `PUDU_DESKTOP_DEV=1` and the frontend directory as
  `PUDU_DESKTOP_ASSETS`, forwarding the program's output; a backend change restarts the program and a
  frontend change reloads or restyles the views ([[Std Desktop App]]).
- `types` runs the entry with `PUDU_DESKTOP_TYPES` set and writes `<frontend>/pudu.ts` by default.
- `build` strips a copy of the running compiler and attaches the program to it with
  `pudu build --runtime`, so the shipped executable carries no symbol tables; without `strip` it
  attaches to the compiler unchanged.
- `bundle` builds (unless `--executable` names one built elsewhere), packs the frontend (source maps
  dropped unless configured), writes every configured format, and — when
  `PUDU_DESKTOP_SIGNING_KEY` names a secret key file — writes the update archive with its signature
  file beside it.
- `keygen` writes a secret key file readable only by its owner and prints the public key for
  `updater.publicKey`; it refuses to overwrite an existing file.
- Every failure prints one line naming what failed and exits with status 1.

## Grill Log

- **Q:** Why is the tool a Pudu program rather than compiler code? **A:** Packaging is file and
  process work the standard library already does; written in Pudu it is the same code an
  application can call, and it exercises the library it ships with.

## Dependencies and consumers

Uses [[Std Desktop Bundle]], [[Std Desktop Bundle Config]], [[Std Desktop Protocol]],
[[Std Desktop Update]], [[Std Desktop Delta]], [[Std Crypto Sign]], [[Std Desktop Cli Template]],
[[Std Process]], [[Std Env]] and [[Std Fs]]. Started by `pudu desktop` ([[Pudu CLI]]).

## Referenced by

[[src/Std/_MOC]] · [[architecture/DESKTOP-WEBVIEW]]
