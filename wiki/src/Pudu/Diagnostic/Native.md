---
type: module
path: "@root/src/Pudu/Diagnostic/Native.hs"
fidelity: Active
domain: "[[Diagnostic]]"
subsystem: "[[Backend]]"
grammar: "[[grammar/haskell]]"
tags: [module, diagnostics, backend]
aliases: [Diagnostic Native, Native Diagnostics]
---

# Diagnostic Native

## Purpose and interface

The single module that owns every diagnostic the native compilation path can
raise, so the `E6xxx` family has one home and the code registry sees each code
exactly once. Refusals about the program (`E6001`) and failures of the native
toolchain (`E6002`–`E6006`) are built here as ordinary [[Diagnostic Model]]
values with the construct's span; the caller renders them exactly like any
other diagnostic.

```haskell
nativeRefusal :: Span -> Text -> Diagnostic            -- E6001
toolchainNotFound :: Span -> Text -> Diagnostic        -- E6002
toolchainInvocationFailed :: Span -> Text -> Diagnostic -- E6003
toolchainTimedOut :: Span -> Int -> Diagnostic         -- E6004
toolchainRejected :: Span -> Text -> Diagnostic        -- E6005
toolchainPublishFailed :: Span -> Text -> Diagnostic   -- E6006
```

Message contracts:

- `E6001` — `the native backend does not support <construct> yet`, help names
  the supported subset and the interpreter as the way to run the program.
- `E6002` — the C compiler could not be found, naming what was searched
  (`PUDU_CC` or `cc`) and how to point at one.
- `E6003` — the compiler could not be started, with the operating system's
  reason.
- `E6004` — the compiler did not finish within the bounded wait, naming the
  seconds.
- `E6005` — the compiler rejected the generated C, with its captured output
  bounded and marked when truncated.
- `E6006` — the compiled executable could not be published to the output
  path, with the operating system's reason.

## Governance

- All six codes are errors; none has related notes; only `E6001` and `E6002`
  carry help.
- Spans point at the program being built: a refusal at the refused construct,
  a toolchain failure at the root module's first token. The interpreter's
  renderer then shows a real file and line, never a fabricated location.
- Messages state what happened and what to do; they never suggest installing
  software or retrying blindly.

## Negative Logic (Prohibited Paths)

- No diagnostic from this module is a warning, and none is suppressed by lint
  policy.
- No toolchain failure is rendered as a compiler crash: the compiler's own
  output is quoted as captured, bounded, and attributed to the toolchain.
- No second module may raise an `E6xxx` code; that is what keeps the family's
  meaning in one place.

## Dependencies and consumers

Requires [[Diagnostic Model]] and [[Source]] spans. Consumed by [[Compiler
Lower]] and the `pudu build --native` path in [[Pudu CLI]]. [[Backend
Runtime]] prints byte-compatible text for `E7004`/`E7005`, but those codes
belong to [[Diagnostic Arithmetic]], not here.

## Grill Log

- **Q:** Why does the toolchain failure carry the root module's span instead
  of no span? **A:** A `Diagnostic` without a location cannot be rendered with
  an excerpt and would name a file no reader has; pointing at line 1 of the
  program being built is the one honest location, and the message carries the
  environment detail. _Rejected:_ spanless diagnostics and synthetic file
  names.
- **Q:** Why one module for six codes when the registry only forbids sharing?
  **A:** The family is the unit a reader looks up; one module makes "what can
  native compilation tell me" a single page and a single mirror, and it keeps
  message wording reviewable in one diff. _Rejected:_ codes split across
  lowering, the emitter, and the CLI.
- **Q:** Why is the compiler's output in `E6005` bounded before construction?
  **A:** A `Diagnostic` is a value that may be logged, cached, or rendered
  many times; bounding at construction is the only point where the bound
  cannot be bypassed. _Rejected:_ truncation at render time.

## Referenced by

[[src/Pudu/_MOC]] · [[src/Pudu/_MOC]] · [[Compiler Lower]] ·
[[Backend Toolchain]] · [[Pudu CLI]] · [[Backend]]
