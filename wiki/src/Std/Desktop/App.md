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
- Each view gets a fresh 128-bit invoke key from the secure random source, a data store named by
  the canonical JSON pair `[app.name, view.label]`, and the bridge as its first script. `name` is
  the stable logical storage namespace: changing it creates fresh storage; the same name and label
  intentionally reuse storage under the same launcher. Legacy label-only stores are bypassed.
- Requests: the reserved commands `pudu:emit`, `pudu:console`, `pudu:window` and `pudu:devtools` are answered through a const
  factory table after the invoke key is checked; other `/.pudu/ipc/` calls go to [[Std Desktop Ipc]]
  `dispatch`; everything else is an asset from [[Std Desktop Protocol]]. A frontend event `name`
  reaches listeners only when a capability grants the command `event:<name>` to the view.
- A request the page stopped waiting for is dropped silently; any other respond failure ends `run`.
- A close request closes that window; `run` returns `Ok` when none remain. A crashed view is
  reloaded. A blocked navigation to `http` or `https` opens in the system browser when
  `openExternal` is set.

- `devtools` explicitly enables release inspection; `openDevtools` controls automatic opening in
  development. `rememberWindows` persists known placements. `ViewPlan.fileDrop` intercepts file drops.
- `Chrome.observe` updates state and emits per-window notifications before handling each event.
  Both platform close requests and frontend close actions use the same persistence and teardown.

## Grill Log

- **Q:** Why is the loop owned by the library rather than written by each application? **A:** Every
  application needs the same routing, key checks and shutdown order, and each hand-written copy is a
  place to forget one. Applications extend it through commands, listeners, plugins and `tick`.
- **Q:** Why poll the frontend directory instead of a file-system notification? **A:** Polling the
  modification times of a frontend's files costs little at this interval, behaves the same on every
  platform, and needs no new runtime effect.
- **Q:** Can a common view label share data across applications? **A:** Distinct logical names
  must remain separate. Encode both names as a JSON pair to prevent delimiter collisions. Do not
  migrate an old label-only store: it may contain data from several unrelated applications.

## Dependencies and consumers

Uses [[Std Desktop Webview]], [[Std Desktop Protocol]], [[Std Desktop Ipc]], [[Std Desktop Bridge]],
[[Std Desktop Capability]], [[Std Desktop Plugin]], [[Std Desktop Chrome]], [[Std Desktop Window]],
[[Std Desktop Reload]], [[Std Env]], [[Std Process]], [[Std Hex]], [[Std Io]], [[Std Json]] and
[[Std Path]].
Consumed by applications and by [[Std Desktop Cli]] templates.

## Referenced by

[[src/Std/_MOC]] · [[architecture/DESKTOP-WEBVIEW]]

## Window integration contract

Resolved Grill Log: reserved handlers return both a response and backend commands. Respond before
closing; retain the returned Loop. Observe every event through Chrome before handling it, so state
queries and placement persistence see the latest platform event. Window close paths share cleanup.
Initial window-state queries are optional probes outside the startup batch: unsupported commands
on existing adapters must not prevent application startup. Inspector auto-open is development-only.
An unsupported inspector shortcut returns an IPC failure without terminating the application.

Resolved Grill Log: frontend modification snapshots and change classification live in
[[Std Desktop Reload]]. Startup batches flush before optional pre-realization native permissions;
unsupported optional records cannot abort startup. Execute window controls before answering IPC
so a native refusal becomes a typed failure without ending the loop. Close remains response-first.

Resolved Grill Log: send optional window-authority records with the action, origin and the view invoke key before realization. Old window-action records remain for the macOS native frame-metadata path; adapters refuse unsupported optional records without preventing startup.

Resolved Grill Log: `Webview.Refused(_, why)` ends `run` with `Platform(why)`. The application asked
for a view the platform would not admit, such as private storage the runtime cannot provide;
continuing would show a window without the requested view, and retrying cannot succeed.
