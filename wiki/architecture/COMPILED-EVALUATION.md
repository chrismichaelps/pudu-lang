---
type: architecture
tags: [architecture, runtime, performance]
aliases: [Compiled Evaluation]
---

# Compiled Evaluation

## Problem

The evaluator walks the syntax tree every time code runs. Each step decides again what it is looking
at, finds a variable by name through a stack of maps, chooses an operator by its spelling, and
returns a freshly allocated result. Measured at -O2, one evaluated step costs one to two
microseconds, against tens of nanoseconds for the same native map operation:

| Workload | Pudu | Same work, native |
|---|---|---|
| 640,000 multimap adds and lookups | 7.8 s | 0.37 s |
| 3,000,000-iteration arithmetic loop | 2.8 s | 0.24 s |

Every Std module pays this, so no library change closes the gap; the fix belongs at the lowest
layer, where every module above inherits it.

## Decision

Compile each checked function once, before it first runs, into a tree of closures, and run the
closures. Everything the tree walker decides per step is decided once at compile time:

- **Variables become slots.** A name resolves to a frame depth and an index. A frame is a mutable
  array allocated once per call; a read is one index, an assignment one write.
- **Operators become direct functions.** `+` on two integers compiles to the integer addition with
  its overflow check, chosen by the operand types the checker already proved.
- **Fields become positions.** A record's layout is known after checking, so `point.x` compiles to
  reading position 0.
- **Calls are direct.** A call to a known function holds its compiled body; only a call through a
  function value looks one up.
- **Control flow uses result codes, not allocation.** `return`, `break`, and `continue` travel as a
  small tag the enclosing loop or call reads, and a normal step allocates nothing.

Values, builtins, effects, and the runtime stores are unchanged; only how code runs changes.

## Phases

1. **Slot resolution.** After checking, each function body is annotated with slot positions for its
   bindings and the frame depth of every captured name. This is a pure pass over checked syntax.
2. **Closure compilation.** A second pure pass turns each annotated body into closures. A construct
   the compiler does not yet handle compiles to a closure that calls the tree walker for that one
   expression, so coverage grows construct by construct with the language always runnable.
3. **Switch-over.** `pudu run` uses compiled code; the tree walker remains as the reference.

## Correctness

The tree walker is the oracle. Every fixture, and a differential run over generated programs, runs
under both, and their values, output, and diagnostics must be identical. A difference is a compiler
bug by definition. Compile-time evaluation (`const`, `comptime`) keeps the tree walker, whose step
budget and sandbox are already specified.

## Targets

Measured at -O2 against the current release, minimum of five runs:

- tight arithmetic loops and record updates at least five times faster;
- the multimap workload above under 1.5 s;
- no workload slower, and memory no higher.

## Beyond this design

Compiled closures remove interpretation overhead but keep boxed values. Native code generation from
the same slot-resolved form is the next step toward native speed, and is its own decision.

## Grill Log

- **Q:** Keep optimizing the tree walker? **A:** No. _Rationale:_ the safe local wins measured
  12 to 17 percent; the remaining cost is per-step decision and allocation, which only compiling the
  decisions away removes. _Rejected:_ caching lookups inside the tree walker, which keeps every step's
  dispatch.
- **Q:** Bytecode and a virtual machine, or closures? **A:** Closures first. _Rationale:_ they reuse
  the existing value and builtin representations unchanged and let unsupported constructs fall back
  per expression, so the switch is incremental; a bytecode design needs an instruction set and a
  dispatch loop before anything runs. _Rejected:_ bytecode as the first step.
- **Q:** Replace the tree walker? **A:** No; keep it as the oracle and for compile-time evaluation.
  _Rationale:_ a second implementation of the same semantics is the strongest test the compiler can
  have. _Rejected:_ deleting it once the compiler covers the language.

## Referenced by

[[architecture/_MOC]] · [[architecture/PERFORMANCE]] · [[architecture/SEMANTICS]]
