---
type: module
path: "@root/lib/Std/Desktop/Records.pudu"
fidelity: Active
domain: "[[Pudu Program]]"
subsystem: "[[Standard Library]]"
grammar: "[[grammar/pudu]]"
tags: [module, stdlib, desktop, webview]
aliases: [Std Desktop Records]
---

# Std Desktop Records

## Purpose and interface

The Pudu half of the WebView record framing ([[Pudu Webview Records]]): `field`, `encode` and
`encodeAll` write records; `decode` reads the adapter's event bytes into `Array[Array[Str]]` or a
`RecordError` naming the byte offset.

## Semantics

- A field is its UTF-8 byte length, `:`, the bytes, `,`; a record ends with a line feed.
- Decoding refuses a missing length, a length past the end, a missing `,`, a field that is not UTF-8,
  an empty record, and input that ends inside a record — each with the offset where it went wrong.

## Grill Log

- **Q:** Decode fields as `Bytes` or `Str`? **A:** `Str`. Every event the adapter writes is text;
  request bodies travel separately through `webviewBody`, so the framing never carries binary.

## Dependencies and consumers

Consumed by [[Std Desktop Webview]].

## Referenced by

[[src/Std/_MOC]] · [[architecture/DESKTOP-WEBVIEW]]
