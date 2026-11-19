---
type: module
path: "@root/examples/mobile/Remote.pudu"
fidelity: Active
domain: "[[Pudu Native]]"
tags: [module, example, mobile, native, network]
aliases: [Native Remote Example]
---

# Native Remote Example

## Purpose and interface

A program that loads two resources over the network on the iOS simulator through [[Std Mobile Resource]]. It shows two labelled lines, `Profile` and `Limited`, each reporting its status and body: `loading`, `{code} {body}`, or `failed {code} {reason}`.

The base URL comes from `PUDU_FETCH_BASE`, defaulting to `http://127.0.0.1:8080`. The policy is shared by both resources: served for a minute, kept five minutes after nothing shows it, and shown as failed only after three failed attempts.

The profile is described in two places of the screen. The table sends one request for both, and none again while the result is fresh. The limited resource is described once, and the server answers its first request with 429 and Retry-After of one second.

Each line is a memoized subtree keyed by its label record, so a line renders only when its text changes ([[Std Mobile Memo]]).

## Program loop

The program builds the needs, reconciles them against an empty table, and writes the commands. It mounts the view, then waits for host events. For each event it calls `Resource.observe`, reconciles the needs again at the event's time, writes the commands, and updates the view. A stop event ends the loop.

## Invariants

- Two descriptions of the same key produce one request.
- The rate-limited resource is asked again only after its Retry-After delay, and its failure is not shown.

## Negative Logic

- No request is made outside the table. The program never calls the platform directly.
- No URL is built from a timer or a memo. The needs are the only source.

## Self-test and run

The self-test runs with `PUDU_UI_FETCH_TEST` set and `PUDU_UI_SELFTEST` set to 0. It prints `PUDU_FETCH loaded` once both lines show a loaded result, as described in [[pudu_ios_fetch.h]]. The simulator run in [[iOS Simulator Run]] starts a [[Test Fetch Server]] and asserts that the profile was requested once and the limited path twice.

## Dependencies and consumers

Depends on [[Std Mobile Resource]], [[Std Mobile Memo]], [[Std Mobile View]], [[Std Mobile Host]], [[Std Mobile Events]] (through `Host.wait`), [[Std Env]], [[Std Time]] and [[Std Json]]. The host is [[iOS Host Adapter]] with [[pudu_ios_fetch.h]]. Its fixture-level counterpart is [[Uses Mobile Resource]].

## Resolved Grill Log

- **Q:** Why describe the profile twice? **A:** It shows that two places of the screen that need the same key share one request.
- **Q:** Why show a line as loading during a rate-limited wait? **A:** The loaded result is absent, so the status stays pending until the retry succeeds, and no failure is shown before the policy's retries.

## Referenced by

[[src/examples/README]] · [[iOS Simulator Run]] · [[Std Mobile Resource]] · [[pudu_ios_fetch.h]] · [[Test Fetch Server]]
