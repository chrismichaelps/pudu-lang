---
type: module
path: "@root/lib/Std/Desktop/Protocol.pudu"
fidelity: Active
domain: "[[Pudu Program]]"
subsystem: "[[Standard Library]]"
grammar: "[[grammar/pudu]]"
tags: [module, stdlib, desktop, webview, assets]
aliases: [Std Desktop Protocol]
---

# Std Desktop Protocol

## Purpose and interface

Serves the `pudu://app/` origin. `Assets` is a `Directory` on disk or a `Packed` map loaded from one
gzip tar archive. `resolveAsset` turns a URL path into a safe relative path; `serve` answers a
pending request with the asset, its media type and the policy's headers; `walk`, `pack` and
`unpack` move a frontend between a directory and an archive; `ipcCommand` recognizes the reserved
`/.pudu/ipc/<command>` path; `text`, `json` and `bytes` build responses.

## Semantics

- `resolveAsset` percent-decodes the path, then refuses `..` segments, backslashes, NUL, and
  absolute or drive-qualified paths with `Escapes`. An empty path or one ending in `/` names that
  directory's `index.html`.
- Only `GET` and `HEAD` are served (`405` otherwise; `HEAD` answers headers with an empty body). A
  missing asset is `404` unless the policy names a single-page `fallback`, whose content is then
  served with status `200`.
- Every asset response carries the policy's `Content-Security-Policy`, `X-Content-Type-Options:
  nosniff`, the media type (with `charset=utf-8` for text), and `Cache-Control: no-cache`.
- `pack` sorts paths and writes entries with a fixed modification time, so the same frontend packs
  to the same bytes; source maps are left out unless `keepMaps` is set.
- `unpack` refuses an archive whose entry path would escape the root.

## Grill Log

- **Q:** Read from disk per request, or pack into memory? **A:** Both, chosen by the application. A
  directory serves edits instantly in development; a packed archive is one file to install, one
  read at start, and no path a page can probe on disk.
- **Q:** Why `Cache-Control: no-cache`? **A:** The origin is local and the program is the server;
  a cached asset that outlives an update is a correctness bug, and revalidation costs nothing here.

## Dependencies and consumers

Uses [[Std Desktop Webview]], [[Std Archive Tar]], [[Std Compress Gzip]], [[Std Mime]], [[Std Url]] and
[[Std Io]]. Consumed by [[Std Desktop App]], [[Std Desktop Ipc]] and [[Std Desktop Bundle]].

## Referenced by

[[src/Std/_MOC]] · [[architecture/DESKTOP-WEBVIEW]]
