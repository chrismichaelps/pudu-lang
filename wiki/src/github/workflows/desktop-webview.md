---
type: module
path: "@root/.github/workflows/desktop-webview.yml"
fidelity: Active
aliases: [Desktop Webview CI]
tags: [module, test, delivery, desktop]
---
# Desktop Webview CI

For changes to the WebView adapters, their native tests, or the page bridge: on macOS, run
[[Webview Records Test]], link [[Webview Drive Harness]] with the WebKit adapter and run it, and run
the bridge tests with the generator check; on Ubuntu 24.04, install WebKitGTK and a virtual
display, run the records test, and link the harness with [[Pudu Webview GTK Adapter]] under
`xvfb-run`; on Windows, fetch the WebView2 SDK, run the records test, and link the harness with
[[Pudu Webview Windows Adapter]]. These native harness jobs need no compiler build.

## Resolved Grill Log

- **Q:** Why retain native harness jobs alongside the compiler application job? **A:** The harness
  exercises the six entry points directly and pinpoints native failures. The application job
  additionally checks evaluator linkage, library routing and run-loop behavior.

## Referenced by

[[github/workflows/ci]] · [[architecture/DESKTOP-WEBVIEW]]

Resolved Grill Log: the macOS harness links the same window unit as the compiler.

Resolved Grill Log: link the GTK window and interaction units into the same native harness used for the adapter. Run window state/control assertions on Linux as well as macOS.

Resolved Grill Log: install and start Openbox inside the virtual display to verify native window-manager state transitions.

Resolved Grill Log: link GTK Context and exercise default isolation through actual page storage.

## GTK-enabled application conformance

Resolved Grill Log: build the actual compiler with `webkitgtk`, `-Werror` and tests disabled, then
run the two-window lifecycle fixture and Notes in development mode under a window manager. A plain
C adapter test cannot prove evaluator linkage, library routing or run-loop integration. Changes to
desktop library modules, examples, fixtures, runtime linkage or the package manifest trigger this
workflow as well as native adapter changes. The application job uses its own SDK-enabled cache.

The application job also requires [[Desktop Application Isolation Fixture]] to keep separate
logical applications and delimiter-bearing store names isolated through actual page storage.

Resolved Grill Log: the application shell stops on every failed output assertion, and CI retains the window/example logs for review.

Resolved Grill Log: the GTK application build installs the terminal development library required by the CLI dependency graph, in addition to the native display SDK.

Resolved Grill Log: the Windows job links the window geometry unit into its production adapter.
It also runs [[Webview Windows Window Harness]] independently of renderer startup to check actual
geometry, native tracking, menu-aware limits and transactional argument refusal.

Resolved Grill Log: compile and run [[Webview Windows Handler Harness]] against the same SDK to
verify failed, synchronous and retained callback creation references are released correctly.

Resolved Grill Log: native test path filters cover both C and C++ harness sources.

Resolved Grill Log: both Windows adapter harness links include the extracted environment and
request units, matching the package manifest's production source set.

Resolved Grill Log: both Windows adapter links include policy JSON and compiled policy units. Policy tests exercise parsing, transactional installation and matching separately from live renderer/network conformance.

Resolved Grill Log: run the portable JSON harness and the Windows policy harness plus generated-script gate. Preserve the separate live renderer/network proof requirement.

Resolved Grill Log: native policy network conformance uses a real loopback first-party page and seeded cookie, with server-side endpoint/body assertions. The Windows job additionally probes URI upgrade transport; other native jobs initially exercise cookie/block behavior because native default-port upgrade semantics require a distinct fixture.

Resolved Grill Log: a separate isolated Linux HTTPS gate installs a fresh temporary test CA, verifies upgraded POST delivery at real default ports, and removes trust afterward. Its root test sandbox exception does not replace the unprivileged network job.

Resolved Grill Log: add a native SDK UUID fixture, plus a Windows compiler application job using the actual webview2 flag/SDK and matching list-bin flags. Notes IPC and sequential application isolation must execute through the built compiler. Current-delta CI remains unpublished until delivery partitioning.

Resolved Grill Log: the Windows job builds and runs [[Webview Windows Profile Harness]] and
[[Webview Windows Ownership Harness]] against every production Windows unit, including
[[Pudu Webview Windows Profile]]. They are branch evidence from doubles; actual storage
persistence and isolation on the runtime remain separate evidence.

Resolved Grill Log: the real Windows drive includes unnamed isolation. Build
[[Webview Storage Harness]] with the production adapter and run [[Desktop Storage Gate]] for
named-store persistence and explicit/private/unnamed separation across browser exit. Retain both
phase logs as CI artifacts even when the gate fails. This job remains distinct from double-based
profile/ownership tests and from compiler application conformance.

Resolved Grill Log: link [[Webview Windows Storage Probe]] into the Windows storage executable;
require native private-mode observation and persistent replay of prior private identities.

Resolved Grill Log: every Windows step that links the complete adapter also compiles
[[Pudu Webview Windows Control]], and the window harness step checks window controls as well as
geometry.
