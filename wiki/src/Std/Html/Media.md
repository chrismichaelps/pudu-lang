---
type: module
path: "@root/lib/Std/Html/Media.pudu"
fidelity: Active
domain: "[[Pudu Program]]"
subsystem: "[[Standard Library]]"
grammar: "[[grammar/pudu]]"
tags: [module, stdlib, html, media, responsive, network-adaptive, low-bandwidth]
aliases: [Std Html Media]
---

# Std Html Media

## Purpose and interface

Network-adaptive responsive media generator optimized for poor network conditions (2G/3G, `Save-Data`) and low-level unboxed byte construction. Dynamically downsizes and tailors HTML `<img>` and `<picture>` elements based on client network telemetry, preventing bandwidth exhaustion, packet drops, and TCP buffer bloat.

Exports:
- `type Priority = Critical | Standard | Low`: Rendering priority determining loading and fetch hints.
- `type SourceRule = { srcset: Str, mediaQuery: Str, typeMime: Str, minWidth: Int }`: Picture source description.
- `adaptiveImage(profile: &Resilience.NetworkProfile, src: Str, alt: Str, width: Int, height: Int, priority: Priority, lqipDataUri: Str) -> Bytes`: Emits an `<img>` tag tuned to the connection speed. On poor networks or `Save-Data`, it falls back to low-quality image placeholder (LQIP) or standard resolution, omitting dense high-res alternatives and enforcing `loading="lazy"`, `decoding="async"`, and `fetchpriority="low"`. On high-speed links with `Priority.Critical`, it enables `loading="eager"` and `fetchpriority="high"`.
- `adaptivePicture(profile: &Resilience.NetworkProfile, defaultSrc: Str, alt: Str, width: Int, height: Int, sources: &Array[SourceRule], priority: Priority) -> Bytes`: Emits a `<picture>` container. Under constrained network conditions, large-screen and high-density source sets (where `minWidth > 800`) are omitted, drastically reducing unnecessary image downloads.

## Complexity and limits

Markup generation executes in $O(N)$ string and byte manipulation where $N$ is the number of sources. Output is rendered as contiguous `Bytes` ready for socket streaming. Attribute strings are HTML escaped.

## Grill Log

- **Q:** Why inspect the network profile when emitting media markup? **A:** High-density images are the single largest source of payload bloat on the web. On 2G/3G networks, a single 2MB hero image will freeze the TCP connection and exhaust the client's radio buffer. Tailoring the markup on the server cuts multi-megabyte payloads to tens of kilobytes before bytes ever touch the wire.
- **Q:** How does LQIP work without client JavaScript? **A:** The LQIP base64 data URI is embedded directly in the `src` attribute under poor network conditions, rendering instantly without an extra round-trip HTTP request.
- **Q:** Are high-density sources always preserved on desktop broadband? **A:** Yes. When `profile.isPoorNetwork` and `profile.saveData` are false, full responsive picture sources and high-priority fetch hints are emitted.

## Dependencies and consumers

- [[Std Bytes]] supplies raw byte sequences.
- [[Std Http Server Resilience]] supplies client network inspection profiles.
- Consumed by enterprise SSR templates, marketing pages, and content catalogs.

## Referenced by

[[src/Std/_MOC]] · [[2026-09-06-application-stack]]
