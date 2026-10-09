---
type: moc
tags: [moc, module]
---

# Evaluator Module Map

- [[Eval Arithmetic Tests]] — scalar operators and tuple-ordering regression checks.

- [[Eval MultiMap]] — fused persistent append and indexed membership beneath Std.MultiMap.

- [[Eval Function Closure Tests]] — receiver, generic, qualified, and missing Decimal dispatch checks.

- [[Eval Runtime]] — scoped resource ownership shared by evaluation modes.
- [[Eval Context]] — serialized accepted-state retention across evaluator actions.

- [[Eval Foreign Result]] — exact non-owning result conversion and shape failures.

- [[Eval Foreign Resource]] — destructor preflight, failed output cleanup, and cleanup diagnostics.

- [[Eval Entropy]] — bounded operating-system cryptographic entropy.
- [[Eval Hash Map]] — persistent indexed buckets and deterministic map order.
- [[Eval Bytes]] — compact byte values and their built-in operations.
- [[Eval Handle]] — runtime-owned streaming file handles.
- [[Eval Socket]] — runtime-owned TCP sockets and typed host outcomes.
- [[Eval Compress]] — bounded gzip compression and decompression through zlib.
- [[Eval Tls]] — secured connections held for one evaluation.
- [[Eval Concurrent]] — thread, channel, mutex, and atomic-cell tables.
- [[Eval Desktop]] — evaluation-owned desktop windows and serialized present/pump/close lifetimes.
- [[Eval Audio Device]] — validated bounded PCM playback through a private target adapter.
- [[Eval Audio Stream]] — evaluation-owned persistent playback, controls, telemetry, and media clock.
- [[Eval Audio Kernel]] — compiled exact waveform and automation loops for bounded PCM slices.
- [[Eval Hash]] — digest, password-derivation, and collection-mixing primitives.
- [[Eval Builtin TextNumber]] — reading the number a whole text spells, for `toInt`, `toFloat`, and `toDecimal`.
- [[Eval Checksum]] — CRC-32, CRC-32C, CRC-64, and FNV-1a over bytes, chained a chunk at a time.
- [[Eval Frozen]] — constant values that are plain data, bound at link instead of evaluated again.
- [[Eval Install]] — a module's declarations into the environment, functions before constants.
- [[Eval Effect]] — the operations that reach outside the program, and the refusal that keeps them out of constant folding.
- [[Eval Builtin]] — the effects, built-in methods, and conversions the prelude wires in.
- [[Eval Builtin Definition]] — the closed wired-in function vocabulary and canonical source names.
- [[Eval Clock]] — calendar time and subprocesses.
- [[Eval Io]] — the effects a program may perform, each answering with an outcome.
- [[Eval Keyed]] — the runtime semantics of `Map` and `Set`, kept in key order by a balanced tree.
- [[Eval Order]] — which values may be keys, and the order they are compared by.
- [[Evaluator]] — declaration installation, statement and expression walking, and bounded execution.
- [[Eval Dispatch]] — array method dispatch (currently inline in Eval.hs, extraction planned).
- [[Eval Capture]] — which names a function literal can reach, so a capture holds only those.
- [[Eval Range]] — what a range is, and what can be asked of one without walking it.
- [[Eval Render]] — how a runtime value prints, and what a diagnostic calls its shape.
- [[Eval Method]] — the closed vocabulary of built-in methods a value answers to, and the name each is spelled by.
- [[Eval Compile]] — function bodies compiled to closures once per run.
- [[Eval Frame]] — one level of bindings, a name map or a compiled body's slots, read by name.
- [[Eval Compile Layout]] — whether a compiled body runs on slots, and where its locals sit.
- [[Eval Compile Cache]] — compiled bodies kept for a run, shared by its threads.
- [[Eval Rope]] — text built by `+` held as chunks, joined once when read.
- [[Eval Sort]] — stable natural merge sort by a program's comparison.
- [[Eval Value]] — runtime values, and the total order the keyed collections are held in.
- [[Eval Foreign]] — the call into a library written elsewhere, and every check made before the value leaves.
- [[Eval Env]] — environment frames, control unwinding, and abort diagnostics.
- [[Eval Match]] — total pattern matching against values.
- [[Eval Operator]] — unary, binary, member, index, and `?` semantics.
- [[Eval Place]] — storing into a variable, a field, an element, or `*r`, and handing a `&mut` loan back.
- [[Eval Array]] — Array[T] runtime values, indexing, iteration, and 42 accessor methods.
- [[Eval Verify]] — runtime verification and integrity assertion preflight.

Dependency direction: Builtin Definition → Value → Env → Operator/Match/Array → Dispatch → Evaluator. No evaluator module imports a parser or resolver module other than [[Syntax Tree]].

- [[Eval Test Coordinator]] — executable registration of evaluator regression properties.
- [[Eval Binding Flow Tests]] — lexical order, branches, transfers and pure loop semantics.

- [[Runtime Series Map]] — pure numeric occurrence storage beneath Value/MultiMap.

- [[Eval Data Tests]] — structural Decimal equality and retained numeric representation.

## Referenced by

[[src/Pudu/_MOC]] · [[Semantics]]

- [[Eval Foreign Binding]] — native metadata extracted unchanged from runtime values.

- [[Eval Loop Kernel]] — complete pure regions, proven MultiMap calls and closed module functions.
- [[Eval Loop Step]] · [[Eval Loop Step Tests]] — strict unboxed region outcomes, structured refusal/transfer and scratch cleanup.

- [[Eval Call Argument]] — argument values and receiver lending places.
- [[Eval Call Needs]] — evaluator callbacks shared by call dispatch and argument discovery.

- [[Mutex Admission Spec]] — bounded admission, ownership and timer retirement.
