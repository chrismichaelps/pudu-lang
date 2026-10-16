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

## Purpose and interface

The C runtime every natively built Pudu program carries inside it: checked
integer helpers, printing, failure rendering, and exit-status clamping. The
runtime is owned here as Haskell text so it ships inside the compiler binary
and no generated program depends on a file next to it, a system header beyond
the C standard library, or a network fetch.

```haskell
data RuntimePart = RuntimePart
  { runtimePartName :: !Text
  , runtimePartLines :: !Text
  }
runtimeParts :: [RuntimePart]
  -- prelude, site, colored, fail, add, sub, mul, div, rem, neg,
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
int64_t pudu_add(int64_t, int64_t, const pudu_site *);
int64_t pudu_sub(int64_t, int64_t, const pudu_site *);
int64_t pudu_mul(int64_t, int64_t, const pudu_site *);
int64_t pudu_div(int64_t, int64_t, const pudu_site *zero, const pudu_site *overflow);
int64_t pudu_rem(int64_t, int64_t, const pudu_site *zero);
int64_t pudu_neg(int64_t, const pudu_site *);
void pudu_print_int(int64_t);
void pudu_print_bool(int);
void pudu_print_str(const char *bytes, size_t length);
int pudu_status(int64_t);
```

## Algorithm and invariants

- The runtime is a fixed, ordered list of named parts: the prelude (includes,
  `INT64_MIN`, the site record, checked-range helpers), the site table, the
  colour decision, the refusal renderer, one part per checked helper, one part
  per printer, and the status clamp. [[Backend Emit]] selects the parts a
  module needs and concatenates them in this order, each followed by a blank
  line, so the translation unit carries exactly the helpers it calls.
- Checked arithmetic is defined for every input: `pudu_add`/`pudu_sub` compare
  against `INT64_MAX`/`INT64_MIN` before adding; `pudu_mul` refuses the two
  `INT64_MIN`/`-1` pairs and otherwise bounds-checks by division; `pudu_div`
  refuses a zero divisor (`E7004`) and `INT64_MIN / -1` (`E7005`, "divide");
  `pudu_rem` refuses only zero, so `INT64_MIN % -1` is `0` exactly as the
  evaluator computes it; `pudu_neg` refuses `INT64_MIN`. No signed overflow or
  division trap can execute.
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
- No allocation: the runtime never calls `malloc`; it needs only the C
  standard library and, for terminal detection, `isatty`.
- No undefined behaviour on any input, including the extremes; no assumption
  that `char` is signed.
- No C source file is read from disk at build or run time: the text is
  compiled into the compiler itself.

## Dependencies and consumers

Consumed by [[Backend Emit]], which selects and concatenates the runtime parts
into every generated translation unit. It depends on nothing in Pudu: the C
side includes only `<stdint.h>`, `<stdio.h>`, `<stdlib.h>`, `<string.h>`, and
`<unistd.h>` or `<io.h>` for `isatty`. Its Haskell side is a literal with no
imports beyond `Data.Text`.

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

## Referenced by

[[src/Pudu/Backend/_MOC]] · [[src/Pudu/_MOC]] · [[Backend Emit]] ·
[[Backend Toolchain]] · [[Diagnostic Arithmetic]] · [[Backend]] ·
[[Compilation Artifact]]
