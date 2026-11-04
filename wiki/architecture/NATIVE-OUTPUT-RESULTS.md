---
type: architecture
aliases: [Native Output Results]
tags: [backend, runtime, io]
---
# Native Output Results

Compile the four output builtins as the checked Result[(), Str] they already
return. Output, argument evaluation, failures, pending data, and subsequent
execution match GHC 9.14.1 with text 2.1.3. No source semantics change.

## Representation

CoreOutputError carries a stdout/stderr selector, a newline flag and one Str
operand. It returns owned error text, empty on success. Compiler Lower Call
binds that outcome once and builds the existing Ok(()) or Err(text) at the
call's exact solved Result type. IOException's rendering is always nonempty,
so the internal empty-success convention loses no failure. FrameOutputError
preserves this single ordered operation; the emitter calls the output runtime.
The legacy effect-only CorePrint stays for isolated IR tests, while source
calls use real Result values. Existing carrier guards cannot erase this type.

## Handle behavior

The native adapter keeps one 8192-byte buffer per stream. stdout is block
buffered unless it is a terminal; stderr is unbuffered. UTF-8 is explicit,
matching Main's handle setup. Data.Text's UTF-8 fast path uses ByteString.hPut,
so line and partial output use the same hPutBuf buffer algorithm, followed by
hFlush. A line's newline belongs to the same write.

If a write fits below capacity, append it before the requested flush. A write
that fills the buffer attempts a flush before publishing its new buffer length.
An oversized write first flushes pending bytes and then writes directly. On
failure the published pending length remains as before that failed flush.
Consequently later calls may fail at hPutBuf instead of hFlush. A line/no-buffer
handle flushes inside hPutBuf; a block handle flushes afterward at hFlush.
Empty writes skip hPutBuf but still flush pending bytes. Preserve these rules
for repeated failures, partial OS writes and empty operations.

Retry interrupted writes. Nonblocking descriptors wait for writability on
EAGAIN as GHC's raw FD adapter does. Map errno to the locked IOException
category and use the target OS description. Results begin with <stdout> or
<stderr> and the actual failing handle operation. SIGPIPE remains caught during
ordinary source execution; fatal diagnostics retain their separate policy.
Process shutdown retries pending output without replacing the source status.

## Resolved Grill Log

- libc buffers do not preserve GHC's pending lengths or operation labels; keep
  an explicit handle buffer and use platform descriptor writes.
- Fixed buffer storage is a host adapter detail, not a public Pudu layout.
- Error text becomes an ordinary owned Str before the typed Result is built.
- Success-only evidence cannot establish output conformance. Cover closed
  pipes, invalid output descriptors, capacity boundaries, repeated errors,
  healthy Unicode/NUL output, Result use and cleanup.
- Portable C11 source may use guarded POSIX/Windows runtime adapters. Polling
  and descriptor APIs stay inside the output runtime, with no backend inference.
- Independent review and complete release gates remain promotion obligations;
  no sub-agents are used in this continuation.

## Source anchors

Installed GHC.Internal.IO.Handle.Text (hPutBuf', bufWrite, bufferChunk),
GHC.Internal.IO.Handle.Internals (flushWriteBuffer), GHC.Internal.IO.FD
(default 8192-byte buffer), GHC.Internal.Foreign.C.Error (errno categories),
and Data.Text.Internal.IO (UTF-8 hPutStr fast path). Actual closed-pipe CLI
probes confirm hFlush/hPutBuf/hPutBuf state changes before implementation.

## Referenced by

[[architecture/_MOC]] · [[Native Output Delivery]] · [[Native Emission Coverage]] ·
[[Native Output Runtime]] · [[Compiler Lower Call]]

## Current evidence

Focused Clang, GCC 15 and ASan/UBSan checks cover direct output Results,
explicit stream bytes, accepted Result-operator failures, owned cleanup,
failed-handle state and entry builder failures. Both tree and compiled
execution supply isolated-process oracles. The historical closed-pipe,
Core-shape, deterministic emission, arithmetic vocabulary and include-hygiene
checks remain regression obligations.

Initially absent stdout/stderr exposed a real startup difference: the locked
GHC runtime reused the missing descriptor for KQUEUE, while native writes
reported EBADF. Actual CLI probes and lsof confirmed the queue endpoint.
The execution-context projection below resolves that case and all seven
missing-standard-descriptor masks in the local differential matrix.
Linux /dev/full, Windows, bootstrap exhaustion, full-suite validation and
independent review remain outstanding; this evidence does not complete the
native emission goal.

## Missing inherited descriptors: resolved execution-context projection

The locked threaded interpreter initializes Event.Manager.new by allocating
its default backend (KQueue on Darwin, EPoll on Linux), followed by
Event.Control.newControl's read/write pipe, whose writer is nonblocking.
At most three standard descriptors can be missing, so these first three
allocations determine the kernel endpoint that replaces each missing one.
Project that observable execution context before native user code: detect
missing inherited descriptors, allocate the same backend endpoint and, only
when holes remain, the control pipe in the same order. Keep those endpoints
process-owned. Healthy inherited descriptors are never replaced.

Resolved Grill Log: this reproduces kernel endpoint types rather than
rewriting EBADF into a guessed errno. The backend endpoint reports the OS's own queue-write error; a standard
descriptor filled by a pipe reader follows the readiness rule below. The pipe writer retains O_NONBLOCK and both pipe
ends retain close-on-exec, matching the control adapter. Run this once at
process entry before source code can allocate descriptors, not lazily at
first output and not when fatal diagnostics restore signal policy.

This is a bounded projection of observable standard-stream state, not an
implementation of the event manager or a claim of complete native concurrency.
Windows and resource-exhaustion/bootstrap failures still require their own
platform evidence before full-emission completion. Tests must cover single
and multiple missing descriptors, not only the originally observed stdout
case. Implementation belongs to Native Process Context.

### Readiness before writes

Multiple missing descriptor probes found another observable FD rule:
GHC.Internal.IO.FD.writeRawBufferPtr polls a blocking standard descriptor
for writability before attempting write, even when write itself would fail.
A standard output replaced by the control pipe's reader therefore blocks,
rather than reporting EBADF. The native adapter must perform the same
readiness check before each raw write, not only after EAGAIN. Test this with
bounded isolated processes and compare their already-flushed output prefixes
as well as terminal outcomes; two timed-out processes are not sufficient
evidence if their prefixes differ.

## Entry-report output

An entry result uses Data.Text.putStrLn's builder, not the source print
primitive. encodeUtf8Builder copies into the existing byte buffer, flushing
full chunks under operation hPut. Its trailing charUtf8 newline reserves four
bytes before emitting one. A block-buffered result is left for process-exit
flush, whose errors are ignored; a terminal result flushes at hFlush. Preserve
this distinction, including pending bytes left by earlier failed source output.

A non-EPIPE builder failure escapes reportResult as a host IOException. The
locked GHC top handler reports the exception type, operation/category/OS
description and the fixed Foreign.C.Error.hs:291:5 HasCallStack frame, then
exits one. EPIPE remains silent with status zero. Reproduce that observable
vocabulary; do not convert the entry result into an unrelated Pudu diagnostic
or silently discard a large-entry failure. The isolated oracle uses the CLI
program name pudu so the comparison includes the actual exception prefix.

Resolved Grill Log: a read-only output accepts a small entry into its buffer
and exits zero after a failed shutdown flush, while a rendered Str of 8189
bytes fails during the newline's four-byte reservation and exits one. Size
boundaries and a Result entry with prior failed output need permanent probes.
The host backtrace template is locked to GHC 9.14.1 and must be revalidated
on any toolchain change. This does not alter the evaluator to excuse native
differences.

### Fatal diagnostic readiness

Fatal reporting also checks stderr writability before emitting its first
byte. A source E7004 after successful output exposed this requirement when
stderr was replaced by the control pipe reader: the interpreter waited while
the previous native renderer exited silently. The shared process adapter now
preserves that wait and the already-flushed prefix. Failed stderr descriptors
and fatal SIGPIPE termination remain distinct terminal outcomes.
