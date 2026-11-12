---
type: module
path: "@root/lib/Std/Desktop/Window.pudu"
fidelity: Active
domain: "[[Pudu Program]]"
subsystem: "[[Standard Library]]"
grammar: "[[grammar/pudu]]"
tags: [module, stdlib, desktop, webview]
aliases: [Std Desktop Window]
---

# Std Desktop Window

## Purpose and interface

Window chrome and state, and the frontend's window API. Builders: `minimize`, `unminimize`,
`maximize`, `unmaximize`, `toggleMaximize`, `setAlwaysOnTop`, `setDecorations`, `setClosable`,
`setMinimizable`, `setMaximizable`, `setResizable`, `setBackground`, `setTitleBar`,
`requestAttention`, `setBadge`, `setContentProtected`, `queryState`, and for views `toggleDevtools`,
`queryDevtools`, `printPage` and `clearData`. `action(window, name, values)` builds the record for one
frontend action through a const factory table; `actions` lists every name.

## Semantics

- A frontend action named `name` runs only when a capability grants the command `window:<name>`
  ([[Std Desktop App]]); there is no grant by default.
- Values arrive as text: flags accept `true`, `false`, `1` and `0`; sizes and positions must be
  non-negative whole numbers; `titlebar` accepts `visible`, `transparent` and `overlay`. A value
  that does not fit is refused with the action named, before anything is sent.
- `close` from the frontend is a close request, handled by the run loop like the close button.

## Grill Log

- **Q:** Why route frontend window control through capabilities rather than always allow it? **A:**
  A page that can hide, move or always-raise its window can mislead the person using it; the
  application states which of those its pages may do, as it does for every other command.

## Dependencies and consumers

Uses [[Std Desktop Webview]]. Consumed by [[Std Desktop App]] and applications.

## Referenced by

[[src/Std/_MOC]] · [[architecture/DESKTOP-WEBVIEW]]

Resolved Grill Log: close is included in the action catalogue, with no arguments.

Resolved Grill Log: the print command builder is named `printPage`, avoiding ambiguity with the language output builtin.
