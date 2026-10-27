---
type: module
path: "@root/src/Pudu/Backend/Runtime.hs"
fidelity: Active
domain: "[[Core IR]]"
subsystem: "[[Backend]]"
grammar: "[[grammar/haskell]]"
tags: [module, backend, runtime]
aliases: [Backend Runtime, Native Runtime]
---

# Backend Runtime

## Frame ownership (#499)

Revision 5 adds a cleanup hook before fail and memory_failure parts. Both source
failure and shared host-memory failure run the hook before exiting. The legacy
call wrapper catalogue remains for isolated old helpers until removal; new frame
emission uses [[Backend Frame Runtime]]. A fail part depends on cleanup; a
memory_failure part depends on cleanup and [[Host Failure Vocabulary]]. The
previous no-allocation claim applies only to scalar arithmetic/printing helpers;
explicit frames allocate checked storage. Resolved Grill Log: preserve source
diagnostic bytes and free scalar frames on all controlled exits; OS kills and
future owned-value cleanup are not claimed.

## Purpose and interface

The C runtime every natively built Pudu program carries inside it: checked
integer helpers, printing, failure rendering, and exit-status clamping. The
runtime is owned here as Haskell text so it ships inside the compiler binary
and no generated program depends on a file next to it, a system header beyond
the C standard library, or a network fetch.

```haskell
data RuntimePart = RuntimePart
  { runtimePartName :: !Text
  , runtimePartLines :: ![Text]
  }
runtimeParts :: [RuntimePart]
  -- prelude, site, colored, fail, call_depth, add, sub, mul, div, rem, neg,
  -- print_int, print_bool, print_str, status
runtimeRevision :: Text -- the contract revision baked into every artifact
```

## Interface (C surface)

```c
typedef struct {
  const char *file; int line; int column;
  const char *code; const char *message; const char *help;
  const char *line_text; int caret_indent; int caret_width;
  int multiline; int has_excerpt;
} pudu_site;

void pudu_fail(const pudu_site *site);
static int64_t pudu_depth; /* the live call depth, entry starts at 1 */
void pudu_enter(const pudu_site *site);
pudu_int pudu_add(pudu_int, pudu_int, pudu_int_kind, const pudu_site *);
pudu_int pudu_sub(pudu_int, pudu_int, pudu_int_kind, const pudu_site *);
pudu_int pudu_mul(pudu_int, pudu_int, pudu_int_kind, const pudu_site *);
pudu_int pudu_div(pudu_int, pudu_int, pudu_int_kind, const pudu_site *zero, const pudu_site *overflow);
pudu_int pudu_rem(pudu_int, pudu_int, const pudu_site *zero);
pudu_int pudu_neg(pudu_int, pudu_int_kind, const pudu_site *);
void pudu_print_int(pudu_int);
void pudu_print_bool(int);
void pudu_print_float(uint64_t);
void pudu_print_str(const char *bytes, size_t length);
int pudu_status(pudu_int);
```

## Algorithm and invariants

- The runtime is a fixed, ordered list of named parts: the prelude (includes,
  `INT64_MIN`, the site record, checked-range helpers), the site table, the
  colour decision, the refusal renderer, the call-depth check, one part per
  checked helper, one part per printer, and the status clamp. [[Backend Emit]]
  selects the parts a module needs and concatenates them in this order, each
  followed by a blank line, so the translation unit carries exactly the helpers
  it calls.
- Call depth is runtime state, not emitted code: `pudu_depth` starts at `0`
  and the emitted C `main` sets it to `1`, so the entry runs at depth 1 exactly
  as the evaluator's entry `descend` counts it. Every call reaches
  `pudu_enter` through an emitted wrapper, and the check is `depth > 4096`
  *before* the increment — the evaluator's own order — so the program aborts on
  the call that would exceed the bound, at the call's own span, with
  [[Diagnostic Evaluation]]'s `E7002` text through the same `pudu_fail`. The
  bound is written into this part from [[Compile Time Limits]]'s
  `callDepthLimit`, so the runtime and the evaluator cannot drift; the wrapper
  emits the decrement after a normal return, because an abort exits and never
  returns.
- [[Backend Runtime Integer]] supplies revision-4 sign/magnitude helpers.
  Checked operations settle mathematical magnitude/sign against generated kind
  limits before returning; saturation clamps and wrapping decodes unsigned bits.
  Division/remainder use unsigned magnitudes after the zero check, preserving
  MIN/-1 and deferred-positive-boundary behavior without signed C division.
  No stored deferred magnitude is narrowed before use.
- `pudu_fail` prints to standard error in the interpreter's exact layout:
  `error[CODE]: message`, `  --> file:line:col`, the gutter and expanded
  source line, the caret row (with ` ...` for a multiline span), and
  `   = help: ...` when present, then flushes and calls `exit(1)` — the
  evaluator's exit status for a runtime refusal.
- Colour is used only when standard output is a terminal and `NO_COLOR` is
  unset — the same decision, made the same way, as the `pudu` executable — and
  is exactly the interpreter's palette (red severity, cyan help, reset).
- `pudu_print_int` prints the decimal form, `pudu_print_bool` prints
  `true`/`false`, `pudu_print_str` writes the literal's bytes; each appends
  `\n` and flushes, matching `print`'s line-at-a-time contract.
- `pudu_status` clamps a result to the process status contract: `0` stays
  `0`, everything else lands in `1..255` — the same arithmetic `reportResult`
  performs in the interpreter.

## Negative Logic (Prohibited Paths)

- No `printf("%d", ...)` for `int64_t`, no `strlen` on user text, no locale
  dependence, no buffered output left unflushed at refusal.
- Arithmetic, printing and diagnostic helpers do not allocate application
  storage. [[Backend Frame Runtime]] owns checked heap allocation for frames.
  Only the C standard library and terminal detection through `isatty` are needed.
- No undefined behaviour on any input, including the extremes; no assumption
  that `char` is signed.
- No C source file is read from disk at build or run time: the text is
  compiled into the compiler itself.

## Dependencies and consumers

Consumed by [[Backend Emit]], which selects and concatenates the runtime parts
into every generated translation unit. It depends on nothing in Pudu: the C
side includes only `<inttypes.h>`, `<stdint.h>`, `<signal.h>`, `<stdio.h>`,
`<stdlib.h>`, `<string.h>`, selected `<float.h>`/`<limits.h>`, and
`<unistd.h>` or `<io.h>` for `isatty`. Its Haskell side imports `Data.Text`
and [[Compile Time Limits]] plus [[Backend Runtime Integer]] and [[Native Floating Runtime]] — pure constants, no frontend, semantic, or
evaluator module — so the depth bound is the evaluator's own.

## Grill Log

- **Q:** Why embed C text in Haskell rather than keep a `.c` file in the
  package? **A:** A file on disk is a second artefact to locate at run time —
  it breaks for a packaged compiler moved elsewhere, and its path becomes an
  installation contract. Embedding makes the compiler self-contained and the
  runtime revision part of the compiler's own bytes. _Rejected:_ data files
  and runtime lookup paths.
- **Q:** Why is the runtime a list of named parts rather than one string?
  **A:** `clang -Wall -Wextra` flags an unused `static inline` helper
  (`-Wunused-function`), and the toolchain's contract is a warning-free
  translation unit; named parts let emission carry exactly the helpers the
  module calls, keep each helper's text in one place, and make "what does this
  program need" a walk over the core module rather than a guess. _Rejected:_
  one opaque string with suppression pragmas.
- **Q:** Why is the refusal renderer written in C instead of reusing
  [[Diagnostic Render]]? **A:** The running program has no Haskell; the
  runtime must render the same text in C. Parity is kept structural by baking
  the message, help, and excerpt geometry at emission time from the same
  Haskell sources, and by the differential conformance tests that compare the
  two renderings byte for byte. _Rejected:_ a runtime dependency on the
  compiler binary.
- **Q:** Why `exit(1)` rather than `abort()` or a signal? **A:** The
  interpreter exits with status 1 on a refused program and flushes its output;
  `exit` is the only C call that reproduces both facts portably. _Rejected:_
  `abort`, `_Exit`.
- **Q:** Why does the runtime flush after every line? **A:** `print` in the
  interpreter writes a whole line immediately; a native build that buffered
  output would show different interleaving with diagnostics on a shared
  terminal, which is exactly the difference the conformance tests compare.
  _Rejected:_ relying on process-exit flushing.
- **Q:** Why is the call depth a runtime global instead of an emitted
  parameter? **A:** The evaluator keeps depth as environment state, not as an
  argument; a global with a checked `pudu_enter` is that state in C, and it
  keeps the emitted wrapper a call plus a decrement rather than a second
  calling convention. _Rejected:_ passing depth through every signature.
- **Q:** Why is the bound written from [[Compile Time Limits]] rather than
  repeated as a literal? **A:** The evaluator's bound is the contract; a second
  literal here would be a copy that can silently disagree, and the runtime part
  is generated text anyway, so baking the one constant costs nothing.
  _Rejected:_ a `#define` in the prelude and a literal here.

## Referenced by

[[src/Pudu/Backend/_MOC]] · [[src/Pudu/_MOC]] · [[Backend Emit]] ·
[[Backend Toolchain]] · [[Diagnostic Arithmetic]] · [[Backend]] ·
[[Compilation Artifact]]

## Strict C11 terminal detection

Use the standard output descriptor `1` with `isatty`/`_isatty`, avoiding `fileno` whose POSIX declaration is hidden by strict C11 on glibc. Resolved Grill Log: terminal detection has no stream mutation and needs no feature-test macro or compiler extension.

## Platform Int operators (#495)

Catalogue [[Backend Runtime Integer]] parts after existing checked arithmetic and before printers; revision becomes 3 for the added helper ABI. RuntimePart still owns the part wrapper; the Integer module exports name/line pairs to avoid a module cycle.

Resolved Grill Log: use defined unsigned bit patterns, validate counts before shifts, and prove signed arithmetic bounds before evaluation. The actual interpreter determines results, effect order and exact diagnostic vocabulary. No syntax or type-inference change.

## Exact integer carrier integration (#498)

Revision 4 changes the private integer ABI to pudu_int and generated limits.
Remove the old signed checked helpers from this module; Integer.Arithmetic owns
them. Keep diagnostic rendering/depth/IO here. print_int prints a sign and
PRIu64 magnitude, then flushes; status clamps using magnitude/sign. Depth stays
int64_t and unit/Bool retain their ABI. Integer catalogue precedes printers.

Resolved Grill Log: implement [[Exact Native Integer Carriers]] without changing the oracle. Preserve positive boundary values, exact diagnostic provenance, Never transfers, and warning-free helper selection. The internal carrier is not a public type-layout promise; full native coverage remains open.

The revision-4 integer printer emits its sign, magnitude and newline in one printf call, then flushes, keeping the line within one stdio operation.

## Closed-pipe process policy (#505)

Add standard signal.h and process_io/pudu_prepare_io, installing a nonterminating
rearmed SIGPIPE handler where defined at startup. Runtime revision becomes 6.
Add error_io/pudu_prepare_error_io restoring SIG_DFL on fatal stderr paths;
run scalar cleanup before that switch and before stderr rendering. Restore
the startup handler after stderr flush, before exit can retry failed stdout
buffering; failed stderr still terminates under the default disposition.
Resolved Grill Log: match evaluator continuation/later diagnostics, preserve
other signals and later explicit handler changes; no per-print signal reset.
Contract: [[Native Closed Pipe Semantics]].

Scalar refusal sites and their strings are static emitted data, so pre-report
frame cleanup preserves message storage. Future owned error payloads must be
transferred to a surviving error owner before unwinding frames.

## Wide frame bridge (#506)

Revision 7 records the optional wide frame ABI described by [[Native Wide Frame Bridge]]. Preserve the revision-6 process IO policy. Resolved Grill Log: changing frame payload representation requires an artifact revision; helper-only prerequisites did not admit source kinds.

## Floating catalogue integration (#511)

Append [[Native Floating Runtime]] parts after integer parts; retain existing
printer/process behavior and revision 7. Resolved Grill Log: additive helper
publication precedes Core/frame/source admission and no represented ABI changes.

## Runtime revision 8 (#512)

The cell ABI gained a floating member, so `runtimeRevision` moves from 7 to 8.

## Runtime revision 9 (#515)

Text cells and the frame text metadata change the ABI, so the revision is 9.
