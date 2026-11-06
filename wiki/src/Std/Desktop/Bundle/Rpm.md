---
type: module
path: "@root/lib/Std/Desktop/Bundle/Rpm.pudu"
fidelity: Active
domain: "[[Pudu Program]]"
subsystem: "[[Standard Library]]"
grammar: "[[grammar/pudu]]"
tags: [module, stdlib, desktop, packaging, linux]
aliases: [Std Desktop Bundle Rpm]
---

# Std Desktop Bundle Rpm

## Purpose and interface

Writes RPM packages natively. `header` lays out one header structure from tagged values; `rpm`
writes `<pkg>-<version>-1.<arch>.rpm` from the shared Linux layout.

## Semantics

- File order: the 96-byte lead, the signature header padded to eight bytes, the main header, and
  the gzip-compressed `newc` cpio payload whose paths start with `./`.
- Each header starts with its region entry (`62` for the signature, `63` for the main header) whose
  trailer closes the data store, so the header is a well-formed immutable region; entries are sorted
  by tag and integers aligned to their width.
- The signature header carries the main header's SHA-256 (`273`), the size of header plus payload
  (`1000`) and the uncompressed payload size (`1007`).
- The main header names the package, version, release `1`, summary, description, build time, size,
  license, group, URL, OS `linux` and architecture; per-file sizes, modes, devices, times, SHA-256
  digests (digest algorithm `8`), link targets, owners, inodes and languages; compressed file names
  (base names, directory names and indexes); requirements on the WebKitGTK and GTK libraries plus the
  configured ones and the `rpmlib` features the package uses; the payload format, compressor and
  level; and the SHA-256 of the compressed and uncompressed payload (`5092`, `5097`, algorithm `5093`),
  so `rpm -K` verifies both header and payload.
- With `gpgKey`, a detached signature is written beside the package.

## Grill Log

- **Q:** Why not invoke the distribution's build tool? **A:** It needs a spec file, a build root
  and the tool itself, which macOS and most CI images lack; the package format is a fixed binary
  layout this module writes in full, so an RPM can be produced wherever the bundler runs. The gate
  validates the output with `rpm` itself.

## Dependencies and consumers

Uses [[Std Desktop Bundle Binary]], [[Std Desktop Bundle Config]], [[Std Desktop Bundle Linux]] and
[[Std Compress Gzip]]. Consumed by [[Std Desktop Bundle]].

## Referenced by

[[src/Std/_MOC]]
