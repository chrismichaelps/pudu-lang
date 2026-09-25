---
type: module
path: "@root/src/Pudu/Lsp/Scheduler.hs"
fidelity: Active
domain: "[[Compilation Artifact]]"
subsystem: "[[Tooling]]"
grammar: "[[grammar/haskell]]"
depth_score: 0.5
depth_status: SHALLOW
tags: [module, shallow, tooling, lsp, concurrency]
aliases: [Lsp Scheduler]
---

# LSP Scheduler

## Purpose

Read the client's messages on a thread of their own, so that a cancellation or a newer edit is seen
while an analysis is still running, and so that work no client still needs is dropped or stopped
instead of being finished before anything newer is read.

## Interface

```haskell
type Step state = state -> Message -> IO (state, [Text])
requestCancelled :: Int   -- -32800
schedule :: IO Incoming -> (Text -> IO ()) -> (Text -> IO ()) -> Step state -> state -> IO (Either Text ())
```

`schedule next write logLine step initial` serves until the stream ends (`Right ()`), `exit` is
handled (`Right ()`), or a frame cannot be found (`Left reason`). `write` must write a frame whole
when called from two threads at once; the server guards it with one lock.

### Governance

- **One reader, one worker.** The reader queues every message; the worker handles them one at a
  time, in order, each step on a thread recorded as the active work before it starts, so an
  interruption always finds it. No thread is started per message beyond that one step.
- **Cancellation.** `$/cancelRequest` for a request still queued removes it and answers it at once
  with `requestCancelled`; it never runs. For the request being worked on it interrupts the step,
  which is then answered with `requestCancelled`. A request that finished before the interruption
  landed keeps its real answer. Either way a request is answered exactly once.
- **Coalescing.** The server syncs whole texts, so a newer `didChange` for a document makes every
  older one for it pointless when no request waits between them: those are dropped from the queue
  as the newer one arrives, and an analysis of the older text still running is interrupted. When a
  request waits between them, the older text is what the request was asked of, so it is kept. The
  queue therefore holds at most one change per document between two requests.
- **State.** A step's new state is kept only when it finishes, so interrupted work changes nothing
  the server holds and publishes nothing. Frames are written only after the step finishes.
- **Failure.** An ordinary failure in a step is logged and answered with an internal error to the
  request that caused it; an interruption is not a failure. A reader that fails ends the session as
  an unframed stream does, rather than leaving the worker waiting.

### Linkage

- **Requires:** [[Lsp Protocol]], [[Lsp Json]].
- **Consumed by:** [[Lsp Server]]; tested with gated steps in the scheduler spec and over stdio in
  `test/lsp-robustness.mjs`.

## Negative Logic (Prohibited Paths)

- Do not drop a change a waiting request was asked of.
- Do not keep the state of an interrupted step, or write its frames.
- Do not answer a request twice, or leave a cancelled one unanswered.
- Do not fork a thread per message.

## Grill Log

- **Q:** Why interrupt with an asynchronous exception instead of polling a cancellation flag in the
  compiler? **A:** The compiler is pure between its reads and writes and has no natural place to
  poll. _Rationale:_ the only IO an analysis does that must not be cut short is writing a cache
  entry, and that write masks interruptions and removes its partial file ([[Compiler Cache]]).
  _Rejected:_ threading a token through every compiler phase.
- **Q:** Why coalesce as a change is queued rather than when it is taken? **A:** Dropping on arrival
  bounds the queue by the number of requests, however fast the client types; the condition is the
  same either way, since nothing can be inserted between two queued messages later.

## Referenced by

[[src/Pudu/Lsp/_MOC]] · [[Lsp Server]]
