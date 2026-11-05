---
type: module
path: "@root/lib/Std/Desktop/Native.pudu"
fidelity: Active
domain: "[[Pudu Program]]"
subsystem: "[[Standard Library]]"
grammar: "[[grammar/pudu]]"
tags: [module, stdlib, desktop, hybrid]
aliases: [Std Desktop Native]
---

# Std Desktop Native

## Purpose and interface

Native components beside WebView content. `Entry` describes a menu bar (`Submenu`, `Item`,
`Divider`); `menuBar` writes its record. `openFiles`, `saveFile` and `message` write dialog records
answered by a ticket. `surface`, `present` and `closeSurface` place a native pixel surface drawn with
[[Std Ui Canvas]] in a window and replace its pixels.

## Semantics

- Menu lines are written depth first; item names must be unique and non-empty, checked by
  `menuBar` before anything is sent (`DuplicateItem`, `EmptyName`).
- A surface frame is the canvas's RGBA bytes, so the program draws with the same portable
  primitives as the framebuffer desktop and shows them next to HTML.
- Answers arrive as [[Std Desktop Webview]] events: `Chosen(name)`, `DialogAnswered(ticket, paths)`,
  `DialogCancelled(ticket)` and `SurfacePressed(id, x, y)`.
- Targets whose adapter has no native components refuse the records with `Unsupported`.

## Grill Log

- **Q:** Why a separate module from [[Std Ui Menu]]? **A:** That module lays a menu out in pixels
  for the framebuffer desktop; this one describes a platform menu bar. They share the vocabulary of
  names and chords, not the representation.

## Dependencies and consumers

Uses [[Std Desktop Webview]], [[Std Ui Canvas]] and [[Std Bytes]]. Consumed by applications.

## Referenced by

[[src/Std/_MOC]] · [[architecture/DESKTOP-WEBVIEW]]
