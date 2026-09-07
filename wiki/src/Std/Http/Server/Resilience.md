---
type: module
path: "@root/lib/Std/Http/Server/Resilience.pudu"
fidelity: Active
domain: "[[Pudu Program]]"
subsystem: "[[Standard Library]]"
grammar: "[[grammar/pudu]]"
tags: [module, stdlib, http, resilience, network, 2g, 3g, save-data, tcp]
aliases: [Std Http Server Resilience]
---

# Std Http Server Resilience

## Purpose and interface

Network-aware adaptive delivery and transport resilience for constrained mobile connections (2G/3G, high latency, packet loss) and enterprise cache policies.

Exports:
- `NetworkProfile = FastBroadband | ConstrainedCellular(Str) | SaveDataActive`: Client connection classification.
- `inspectClientNetwork(headers: &Array[(Str, Str)]) -> NetworkProfile`: Parses Client Hints (`ECT: 2g|3g|4g`, `RTT`, `Downlink`) and the `Save-Data` header.
- `enforceInitcwndBudget(payload: &Bytes, maxBytes: Int) -> Result[Bytes, Str]`: Enforces strict delivery budgets (default 14,000 bytes $\le$ 14,600 bytes TCP initial congestion window), ensuring early flush shells render in a single round-trip (1-RTT).
- `swrHeaders(maxAgeSeconds: Int, swrSeconds: Int, tags: &Array[Str]) -> Array[(Str, Str)]`: Produces RFC 5861 `Cache-Control: public, max-age=..., stale-while-revalidate=...` and `Cache-Tags` response headers.
- `selectAdaptivePayload(profile: &NetworkProfile, full: &Bytes, minimal: &Bytes) -> Bytes`: Selects lightweight payloads when client is on cellular 2G/3G or has activated data saver mode.

## Complexity and limits

Header inspection is $O(H)$ over incoming request headers. Budget enforcement evaluates byte length in $O(1)$. SWR headers use standard string formatting. The TCP initial congestion window constant assumes standard RFC 6928 `initcwnd = 10` segments (~14.6 KB).

## Grill Log

- **Q:** Why enforce a 14 KB budget on early flush? **A:** Exceeding 14.6 KB requires a second TCP round trip before the browser can parse and render the document head. On high-latency 2G/3G connections (300-800ms RTT), staying under 14 KB delivers the first render cycle in a single round trip.
- **Q:** How is `Save-Data` respected? **A:** When `Save-Data: on` is present, `inspectClientNetwork` classifies the client as `SaveDataActive`, instructing routes to drop decorative images, defer non-critical scripts, and deliver minimal accessible markup.
- **Q:** Does SWR require an external CDN? **A:** No; SWR headers are standard HTTP directives respected by downstream edge nodes, browsers, and application-level caches alike.

## Dependencies and consumers

- [[Std Bytes]] supplies byte measurements.
- [[Std Http Message]] supplies header inspection.
- Consumed by enterprise web application servers.

## Referenced by

[[src/Std/_MOC]] · [[2026-09-06-application-stack]]
