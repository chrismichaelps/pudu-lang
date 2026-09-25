---
type: module
path: "@root/lib/Std/Mime.pudu"
fidelity: Active
tags: [module, stdlib, mime, http, media-type]
aliases: [Std Mime]
---
# Std Mime

## Purpose

Parse, format, classify, and negotiate Multipurpose Internet Mail Extensions (MIME) Media Types (RFC 2045, RFC 6838).
Provides an authoritative registry of over 60 common file extensions and media types, and implements HTTP `Accept` content negotiation.

## Interface

### Types
- `MediaType = { primaryType: Str, subType: Str, parameters: Array[(Str, Str)] }`: Structured media type representation.

### Parsing & Formatting
- `parse(input: Str) -> Option[MediaType]`: Parses media type strings such as `application/json; charset=utf-8`.
- `format(media: &MediaType) -> Str`: Serializes a structured `MediaType` back to canonical wire format.
- `parameter(media: &MediaType, name: Str) -> Option[Str]`: Extracts a named parameter value (case-insensitive).

### Extension Registry
- `fromExtension(ext: Str) -> Str`: Maps a file extension (e.g. `"json"`, `".png"`, `"html"`) to its canonical MIME type string. Defaults to `"application/octet-stream"` for unknown extensions.
- `toExtension(mime: Str) -> Option[Str]`: Maps a canonical MIME type back to its primary file extension.

### Content Negotiation
- `matches(pattern: Str, target: Str) -> Bool`: Tests if a target media type satisfies a pattern (supporting wildcards `*/*` and `type/*`).
- `negotiate(acceptHeader: Str, available: Array[Str]) -> Option[Str]`: Selects the highest quality matching media type from `available` according to RFC 7231 `Accept` quality values (`q=0.9`).

## Algorithm and boundaries

Media types are parsed strictly following RFC 2045 BNF: tokens are separated by `/`, followed by semicolon-delimited parameters (`key=value`).
Quoted parameter values are stripped of their wrapping quotes; the text between them is kept as written.
Type, subtype, and parameter names are compared lower case, and surrounding whitespace is removed with the built-in `trim`.
The extension registry is two module constants, `EXTENSION_TYPES` and `TYPE_EXTENSIONS`, read with one map lookup each rather than a chain of comparisons.
Content negotiation parses quality factor weights (`q=0.0` to `q=1.0`) and orders offers by descending quality with the stable `List.sortOn`, so offers of equal quality keep the order the client wrote them in; the first offer, in that order, that matches an available type wins.

## Grill Log

- **Q:** Why include an extension registry in the standard library?
  **A:** Web servers and HTTP response handlers routinely serve static files. Requiring users to hand-roll MIME dictionaries leads to mislabeled headers (e.g. `text/plain` for JavaScript/WASM), breaking browser execution.
- **Q:** How are quality factors handled when omitted?
  **A:** Quality factors default to `1.0` (highest preference) when unspecified, conforming to RFC 7231 §5.3.2.
- **Q:** Order offers of equal quality however the sort leaves them? **A:** No. _Rationale:_ the client
  lists its preferences in order, and a swapping selection sort turned `text/html;q=0.5,
  application/json;q=0.5` into a JSON answer. _Rejected:_ an unstable sort; ranking ties by the
  server's own list.

## Referenced by

[[src/Std/_MOC]] · [[Std Http Server Reply]] · [[architecture/STDLIB]]
