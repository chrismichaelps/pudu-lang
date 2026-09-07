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
Inspired by `java.net.URLConnection`, `javax.activation.MimetypesFileTypeMap`, and Haskell `mime-types`.

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
Quoted parameter values are stripped of wrapping quotes and unescaped.
Content negotiation parses quality factor weights (`q=0.0` to `q=1.0`), sorts offers in descending priority, and selects the most specific matching type among supported candidates.

## Grill Log

- **Q:** Why include an extension registry in the standard library?
  **A:** Web servers and HTTP response handlers routinely serve static files. Requiring users to hand-roll MIME dictionaries leads to mislabeled headers (e.g. `text/plain` for JavaScript/WASM), breaking browser execution.
- **Q:** How are quality factors handled when omitted?
  **A:** Quality factors default to `1.0` (highest preference) when unspecified, conforming to RFC 7231 §5.3.2.

## Referenced by

[[src/Std/_MOC]] · [[Std Http Server Reply]] · [[architecture/STDLIB]]
