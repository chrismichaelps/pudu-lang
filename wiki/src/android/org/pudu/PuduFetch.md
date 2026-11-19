---
type: module
path: "@root/packages/pudu/v0.1/android/org/pudu/PuduFetch.java"
fidelity: Active
subsystem: "[[Backend]]"
tags: [module, native, android, fetch, http, cache, wake]
aliases: [PuduFetch, Native Android Fetch]
---

# PuduFetch

## Purpose and interface

Requests the program sends and the wake it asks for, on the Android host. A request runs on a fixed pool of four worker threads through `HttpURLConnection`, with the platform response cache installed, so a cached response is revalidated with its validators. Every answer crosses to the main thread. The class is called from `PuduBridge.fetch`, `cancelFetch` and `wake`, and from [[pudu_android_routes.h]], which checks each FETCH answer before the program is told anything.

```java
final class PuduFetch
static final int FETCHED = 18, WOKE = 19;
static final int SENT = 0, REPEATED = 1, UNREADABLE = 2;
static int start(int generation, String method, String address, String[] headers, String body)
static void cancel(int generation)
static void wake(long delay)
static long retryAfter(String value)
```

## Behavior

- `start` parses the address first. An address that does not parse answers UNREADABLE. A generation already in flight answers REPEATED. Otherwise the pool is created on first use, the response cache is installed, and the request is submitted under the generation. Headers alternate name and value; an empty body sends no body.
- The cache is an `HttpResponseCache` in the application's cache directory, named `pudu-http`, limited to 16 MB. It is installed once. Failure to install leaves requests going to the network.
- `exchange` opens the connection, sets the method, headers and the caches flag, writes the body with a fixed length when there is one, and reads the status. A status of 400 or more reads the error stream; the body is read as UTF-8. The Retry-After header is converted by `retryAfter`. A failure yields status 0, the failure's message or its class name, and -1.
- The answer is posted to the main thread. A generation that is no longer in flight is dropped: `flights.remove` returns null after a cancel. Otherwise the answer is sent as `PuduBridge.event(FETCHED, generation, text, status, [retryAfter])`.
- A response body is read at most 16 MB. A body past the cap ends the read and answers status 0 with the reason. Connections time out after 15 seconds to connect and 30 seconds to read.
- `cancel` removes the generation from the flight table and interrupts its future. A generation that is unknown or already answered is ignored.
- `wake` replaces the earlier wake: the old runnable is removed from the main handler and a new one posts WOKE after the delay. Each wake sends one WOKE event with tag 0.
- `retryAfter` reads delay seconds, capped at `Integer.MAX_VALUE / 1000` seconds, and returns milliseconds. A value that is not a number is read as an HTTP date in the RFC 1123 form, and the time left until it is returned, at least 0 and at most `Integer.MAX_VALUE`. A missing, blank or unreadable value is -1.

## Invariants

- A FETCHED event is sent at most once per generation, and only for a generation still in flight when the answer reaches the main thread.
- The flight table is touched only on the main thread after the request is submitted, so cancel and answer do not race.
- The wake runnable exists at most once; the last wake replaces the earlier one.

## Negative Logic

- No status 0 answer when a response arrived. Status 0 means nothing arrived, and the text carries the failure reason.
- No retry by the platform. Retry-After is reported to the program, which decides when to send again.
- No request under generation 0; that defect is refused in C before this class is called.

## Dependencies and consumers

Depends on `java.net.HttpURLConnection`, `android.net.http.HttpResponseCache`, the application cache directory on [[PuduBridge]], and the main-thread handler. Called by [[pudu_android_routes.h]] for FETCH, CANCEL and WAKE through [[PuduBridge]]. The iOS counterpart is [[pudu_ios_fetch.h]], which uses a platform URL session with the same answer shape.

## Resolved Grill Log

- **Q:** Why are answers checked against the flight table on the main thread? **A:** A cancel arrives on the program thread and an answer on a worker. Checking the table on the main thread after the post gives one order: a generation cancelled before its answer posts is dropped, and a generation answered before a cancel is no longer in the table.
- **Q:** Why a fixed pool of four workers? **A:** Requests from the program are bounded by the keyed list and the screens it shows. Four workers keep those requests moving without an unbounded number of threads.
- **Q:** Why the platform cache rather than a cache of our own? **A:** The platform cache implements the validators and freshness rules; a second cache would have to reproduce them.

## Referenced by

[[src/cbits/pudu-android-routes]] · [[src/android/org/pudu/PuduActivity]] · [[pudu_ios_fetch.h]] · [[NATIVE-MOBILE]]
