---
type: module
path: "@root/packages/pudu/v0.1/src/Pudu/Cli/RuntimePack.hs"
fidelity: Active
domain: "[[Pudu Program]]"
subsystem: "[[Tooling]]"
grammar: "[[grammar/haskell]]"
tags: [module, tooling, deployment, security]
aliases: [Cli RuntimePack]
---

# Cli RuntimePack

## Purpose

The runtime `pudu build --target` attaches a program to, fetched from the release of the compiler
asking for it instead of built locally.

## Interface

- `data Target = LinuxMusl | Lambda`; `targetNamed`, `targetNames` (`linux-musl-x86_64`,
  `lambda-x86_64`); `runtimeFileFor target`; `sharedFiles` (the musl loader and `libffi`, `libz`,
  `libncursesw`, `libgmp`); `packFiles`.
- `resolvePack :: IO (Either PackProblem FilePath)`; `data PackProblem = Unreachable | NotPublished |
  BadManifest | Tampered | Undecodable | OtherSources | Unwritable`; `renderPackProblem`.

## Algorithm

1. The pack for this compiler lives at `<cache>/runtimes/<version>-<16 hex of source digest>`;
   `<cache>` is `PUDU_RUNTIME_CACHE`, else `$XDG_CACHE_HOME/pudu`, else `~/.cache/pudu`. A
   `.verified` marker there means it is complete and checked; the network is not asked.
2. Otherwise `<base>/pudu-runtime-linux-musl-x86_64.sha256` is fetched, `<base>` being
   `PUDU_RUNTIME_URL` or the release's download address for this version. Each line is
   `<64 hex>  <name>`; any other line is `BadManifest`.
3. Each of `packFiles` is fetched as `<name>.gz`, decompressed, checked against its manifest line
   (`Tampered` on mismatch, `Undecodable` if not gzip), and moved into place from a `.pending` file.
4. Both runtimes must carry this compiler's source digest ([[Pudu Version]]); otherwise
   `OtherSources`. Only then is `.verified` written.
5. Fetches follow up to five redirects; every hop goes through [[Package Http]], which admits
   HTTPS, and plain HTTP only for a loopback host. A non-200 answer is `NotPublished`, whose sentence
   says a checkout-built compiler has no published pack and names `--runtime`.

## Grill Log

- **Q:** Trust the manifest alone? **A:** No; the source digest is checked too. _Rationale:_ the
  manifest proves the bytes are the release's, the digest proves the release matches this compiler,
  which is what lets the checked products travel ([[Version Digest]]).
- **Q:** One tar archive? **A:** One gzip file per entry. _Rationale:_ zlib is already linked;
  a tar reader would be new code in the path of every deployment.
- **Q:** Execute the runtime to ask its version? **A:** Never. _Rationale:_ it is built for another
  platform; its digest is read from its bytes.

## Referenced by

[[Pudu CLI]] · [[Runtime Pack Gate]] · [[architecture/DEPLOYMENT-TARGETS]]
