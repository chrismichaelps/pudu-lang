---
type: module
path: "@root/packages/pudu/v0.1/cbits/pudu_ios_fetch.h"
fidelity: Active
tags: [module, host, ios, native, network, objective-c]
aliases: [iOS Host Fetch, pudu_ios_fetch.h]
---

# pudu_ios_fetch.h

## Purpose and interface

Private network implementation of the iOS host, included once by [[iOS Host Adapter]]. The compiler stages it with the other private headers ([[Native Toolchain Host Sources]]). It sends the requests the program describes on the platform URL session, answers them as FETCHED events, keeps one wake timer for WOKE, and reports memory warnings as MEMORY. The program's rules for which requests to send are in [[Std Mobile Resource]]; this header only executes them.

Entry points:
- `pudu_do_fetch`: the FETCH (38) handler.
- `pudu_do_cancel`: the CANCEL (39) handler.
- `pudu_do_wake`: the WAKE (40) handler.
- `pudu_observe_memory`: registers the memory warning observer, called once at launch.
- `pudu_test_fetch`: the self-test run by `PUDU_UI_FETCH_TEST`.

## Behavior

- One platform URL session, created on first use with the protocol cache policy. The session's delegate queue is the main queue, so answers arrive on the main queue, which the wait's run loop drains. The protocol cache revalidates with ETag and Last-Modified without the program asking.
- FETCH reads the generation, the method, the URL text, a header count, each header's name and value, then the body text. It sets the method, the body and each header on the request, then resumes the task and records it in a table keyed by generation.
- The completion handler removes the generation from the table and queues FETCHED with the generation as its tag, the body text (or the error's description when nothing arrived) as its text, the status as its detail word (0 when no HTTP response arrived), and one word for Retry-After in milliseconds (-1 when absent or unreadable).
- Retry-After is read as delay seconds or as an HTTP date. A delay is clamped to the signed 32-bit range.
- CANCEL removes the generation from the table, cancels its task, and removes any FETCHED event for that generation that is queued but not yet read.
- The completion handler returns without queuing when its generation is no longer in the table. A cancelled generation is therefore never answered, even when its answer was already queued.
- WAKE replaces any earlier wake timer with one that queues WOKE (19) after the given milliseconds.
- A memory warning queues MEMORY (20).
- Self-test `pudu_test_fetch` runs on a 0.1-second timer for at most 30 seconds, against the Remote example [[Native Remote Example]]. It succeeds when a label begins `Profile: 200` and a label begins `Limited: 200`, prints `PUDU_FETCH loaded`, and asks the program to stop. On timeout it writes `pudu: fetch test timed out` to standard error and asks the program to stop.

## Defects

Each defect ends the process through `pudu_stream_defect`, naming the generation:
- A FETCH with generation 0: `sent a request without a generation`.
- A FETCH whose URL cannot be read or has no scheme: `sent a request to an unreadable URL, generation`.
- A FETCH for a generation already in flight: `sent two requests under generation`.

## Invariants

- The table of flights holds exactly the generations in flight. A generation leaves it when it is answered or cancelled, whichever comes first.
- Every answer is queued with the generation it was sent under, so [[Std Mobile Resource]] can drop an answer for a superseded generation.
- A cancelled generation produces no FETCHED event, before or after it is queued.

## Negative Logic

- No retry, backoff or jitter here. The program decides when a request is sent again.
- No caching of bodies. The platform's protocol cache is the only cache.
- No pause in the background and no reachability tracking. Those are not implemented on iOS yet.
- No interpretation of the body or the status. The program reads them.

## Dependencies and consumers

Depends on Foundation for the URL session, timers and run loop, on [[pudu_ios_events.h]] for the queue and its kind constants, and on [[pudu_ios_stream.h]] for the reader and defects. Included by [[iOS Host Adapter]]. Listed in [[pudu-cabal]] and [[HostSources]], staged after [[pudu_ios_refresh.h]].

## Resolved Grill Log

- **Q:** Why does the header drop queued answers on cancel as well as ignoring late ones? **A:** A program that cancelled a request must not see its answer when it next reads an event, even if the answer was already queued.
- **Q:** Why one wake timer? **A:** The program asks for the earliest retry only. A second timer would deliver a WOKE the program no longer needs.

## Referenced by

[[src/cbits/_MOC]] · [[iOS Host Adapter]] · [[iOS Host Events]] · [[Std Mobile Stream]] · [[Std Mobile Resource]] · [[Native Remote Example]]
