---
type: module
path: "@root/lib/Std/Desktop/App.pudu"
fidelity: Active
domain: "[[Pudu Program]]"
subsystem: "[[Standard Library]]"
grammar: "[[grammar/pudu]]"
tags: [module, stdlib, desktop, webview]
aliases: [Std Desktop App]
---

# Std Desktop App

## Purpose and interface

The application and its run loop. `App` holds the assets, policy, command registry, capability
grants, plugins, window plans, development settings, frontend event listeners and an optional
per-turn `tick`. `newApp(name, commands, grants)` gives one window with one view of `index.html`;
`windowPlan` and `viewPlan` build plans; `locateAssets` finds the installed frontend; `run` opens everything,
answers every request, and returns when the last window closes.

## Semantics

- With `PUDU_DESKTOP_TYPES=<path>` set, `run` writes `Ipc.typescript` there and returns without
  opening a window; `pudu desktop types` uses this.
- With `PUDU_DESKTOP_DEV=1`, every view is inspectable, console errors from the page are printed
  with their source position, a configured `devUrl` replaces the bundled origin (and is added to the
  navigation allowlist), and the frontend directory is rescanned about every 300 ms: a change only
  to style sheets swaps them in place, any other change reloads every view.
- Every plugin is checked before any window opens; one refusal stops the start with
  `PluginRefused`.
- Each view gets a fresh 128-bit invoke key from the secure random source, its own data store named
  by its label, and the bridge as its first script.
- Requests: the reserved commands `pudu:emit` and `pudu:console` are answered through a const
  factory table after the invoke key is checked; other `/.pudu/ipc/` calls go to [[Std Desktop Ipc]]
  `dispatch`; everything else is an asset from [[Std Desktop Protocol]]. A frontend event `name`
  reaches listeners only when a capability grants the command `event:<name>` to the view.
- A request the page stopped waiting for is dropped silently; any other respond failure ends `run`.
- A close request closes that window; `run` returns `Ok` when none remain. A crashed view is
  reloaded. A blocked navigation to `http` or `https` opens in the system browser when
  `openExternal` is set.

## Grill Log

- **Q:** Why is the loop owned by the library rather than written by each application? **A:** Every
  application needs the same routing, key checks and shutdown order, and each hand-written copy is a
  place to forget one. Applications extend it through commands, listeners, plugins and `tick`.
- **Q:** Why poll the frontend directory instead of a file-system notification? **A:** Polling the
  modification times of a frontend's files costs little at this interval, behaves the same on every
  platform, and needs no new runtime effect.

## Dependencies and consumers

Uses [[Std Desktop Webview]], [[Std Desktop Protocol]], [[Std Desktop Ipc]], [[Std Desktop Bridge]],
[[Std Desktop Capability]], [[Std Desktop Plugin]], [[Std Fs]], [[Std Env]] and [[Std Process]].
Consumed by applications and by [[Std Desktop Cli]] templates.

## Referenced by

[[src/Std/_MOC]] · [[architecture/DESKTOP-WEBVIEW]]
