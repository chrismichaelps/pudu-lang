---
type: handoff
status: ACTIVE
issue: 833
aliases: [Pudu Desktop Delivery]
tags: [handoff, desktop, webview, ipc, packaging, updates]
---
# Pudu Desktop Delivery

Issue #833 on `feature/833-pudu-desktop` from dev. Roles: Language Architect resolved
[[architecture/DESKTOP-WEBVIEW]] and [[decisions/ADR-0026-a-webview-is-a-renderer]] before source;
Runtime Engineer owns the adapters and [[Eval Webview]]; Standard Library Engineer owns
`Std.Desktop.*` and [[Std Crypto Sign]]; Tooling/Release owns [[Std Desktop Cli]], packaging, the
gate and CI. Independent implementation, Language Architect and Forensic Guardian reviews are
pending; no self-approval.

## Continuation ownership

Role transition: Architect resolves the unfinished window-control integration; Runtime Engineer
owns the macOS window unit and its registration; Standard Library Engineer owns App, Chrome,
Window, Webview, Reload and the generated bridge; Tooling/Release owns focused tests and build wiring.
Preserve the existing desktop changes and unrelated checkouts. Independent review follows validation.
The macOS slice completes window requests and state tracking. The Linux continuation implements
the corresponding native controls and isolation; its native harness and compiler-level application
checks pass. Windows control parity remains open.

## Linux continuation ownership

Role transition: Architect resolves GTK state/chrome and authenticated native-message contracts;
Runtime Engineer owns the GTK host, adapter, context, view, window and interaction units; Tooling/Release
owns native harness assertions, build registration and Linux verification. The application/bridge
changes are limited to authenticated optional native-window configuration. Preserve all preceding
macOS work. Independent implementation/API and forensic review follows focused validation.

Role transition: Architect resolves logical application storage namespacing; Standard Library
Engineer owns the App store producer; Tooling/Release owns ApplicationIsolation and its gate/CI
registration. Independent architectural review accepts JSON-pair namespacing with explicit legacy
store bypass and stable-name documentation. The live regression reproduced cross-application
storage sharing before the fix.

## Delivered

Role transition: Architect resolves Windows geometry before source; Runtime Engineer owns
win.cpp, win.h and win_window.cpp for retained client-size bounds; Tooling/Release owns the
dedicated Windows window harness, build registration and verification. Preserve the preceding
macOS/GTK work. This begins Windows parity with actual geometry rather than successful no-ops.

- macOS WebKit adapter and WebKitGTK adapter (behind `webkitgtk`) for one six-entry record channel.
- `Std.Desktop`: views, protocol, typed IPC with streams and events, generated TypeScript,
  capabilities, plugins, the run loop with development reload, signed and patched updates with
  rollback, packaging for `.app`, `.dmg`, `.deb`, `.rpm`, AppImage, NSIS and MSI, and `pudu desktop`.
- Runtime: Ed25519, `modifiedTime`, `executablePath`, and sidecar programs for signable packages.

## Validation evidence

- [[Desktop Webview Gate]] passes locally, including a live WebView self-test (9/9) on macOS.
- The packaged, signed `Notes.app` launched from `/` without a library path passes the same self-test.
- `dpkg-deb` and `rpm -K` accept the written packages (header and payload digests OK).
- [[Webview Drive Harness]] passes against the macOS adapter locally and in CI, and against the
  WebKitGTK adapter in CI under `xvfb-run`: scheme requests, injected scripts, evaluation,
  navigation refusal, content-rule blocking, two views in one window, menus and surfaces.
- The harness passes against the WebView2 adapter in CI on `windows-latest`. A page waiting on a
  deferred response never saw it until the body moved to a global-memory stream; the trace and probe
  that found it stay in the harness behind `PUDU_HARNESS_TRACE`.

## Open

- Hybrid UI components exist on all three adapters. Dialog answers were not exercised
  automatically, since a person must choose.

- Windows: the WebView2 adapter is verified by the native harness in CI; a compiler built on Windows
  with the `webview2` flag has not been exercised, because CI builds the compiler on Linux only.
- Language bugs found and filed: pudu-lang#834 (generic closure loses a forwarded type argument),
  pudu-lang#835 (a derive cannot see a hand-written implementation from another module),
  pudu-lang#836 (trait implementations for unit are unreachable). The framework avoids each.

- CI on pull request #837 is green: the Linux `-Werror` build, all suite shards, the desktop gate with
  `dpkg-deb`, `rpm -K`, a real `makensis` build and `tsc --strict`, and [[Desktop Webview CI]] on
  macOS, Ubuntu and Windows.

## Continuation status

The window-control continuation is local and uncommitted. Earlier PR/CI evidence above applies to
the committed foundation, not this delta. The loop now retains request results, tracks native state,
validates and scopes frontend actions, reports native refusal through IPC and shares close cleanup.
macOS adds chrome controls and opt-in drag/file-drop behavior; the native drag channel checks its
view grant, exact main-frame origin and current mouse press. Frontend reload logic is in
[[Std Desktop Reload]]. Existing Linux/Windows startup tolerates unsupported optional configuration;
the Linux controls are now native-tested, while Windows still needs its adapter implementation.

Independent review found startup, response-ordering and drag-event defects, plus malformed-value
and filename-encoding gaps. They were corrected before final validation. Independent correctness/API and forensic parity
re-review found no remaining P0–P2 findings; two minor documentation corrections were applied.
The slice exceeds the delivery review-size limit and must be partitioned before publication.

## Continuation validation

- Rebuilt the compiler and native adapter with `-Werror`; the native harness passes the existing
  protocol/render cases plus window controls and an enabled inspector toggle.
- Desktop gate passes: 106 module assertions, 15 bridge tests, generated bridge parity, native
  framing, verified update/rollback paths, package-tool checks, both live window checkpoints and
  clean IPC shutdown, and the Notes live self-test (9/9).
- TypeScript 5.9.3 independently checks the bridge declarations and generated Notes module with
  `--strict`. Focused Pudu formatting and lint checks pass.
- API coverage passes: 4,989 exports, 4,267 reached, 85%, zero undocumented exports.
- Full unoptimized compiler suite with `-Werror` passes (1/1 suites); log:
  `/tmp/pudu-desktop-suite.log`. The complete repository/optimized CI gate has not been rerun.
- The final rebuilt executable passes Notes in development mode (9/9, with automatic inspector
  opening) and the two-window IPC-close fixture. The native harness passes after the final helper
  extraction; adapter/view/window units are 497/499/264 lines.
- Independent review also cleared the late-event guard and the final native helper extraction.

## Linux continuation validation

The task-owned `pudu-desktop-linux-833` container mounts this checkout read-only. Linux native
compilation passes with `-Wall -Wextra -Werror`. The live harness reports native, inspector-toggle,
window-controls, thread-guard, storage-isolation and native-authority success, including actual
Openbox maximize/restore, grow/shrink, overlay/menu geometry, shared request identity and
last-view close/reopen during clearing. The root-container native run disables the platform process
sandbox for this test environment; this does not verify the platform sandbox invariant.

The GHC 9.14.1 compiler build with `webkitgtk`, disabled optimization and `-Werror` passes. The
actual executable passes both WindowLoop checkpoints and clean shutdown, plus development Notes
with automatic inspection (9/9). The final native harness passes all markers, including the
NULL/zero-length header regression and invalid response slices. Its fresh-value storage checks
use monotonic deadlines. The root-container sandbox limitation above also applies to these runs.

Persistent logs are under `/Users/chrismperez/Library/Caches/Pudu/desktop-833/`: `linux-build.log`,
`linux-native.log`, `linux-window-loop.log`, `linux-notes.log`, `linux-application-isolation.log`
and `desktop-gate.log`. The earlier host `/tmp` full-suite log was lost after a host restart;
the earlier recorded result is historical evidence, not a current-delta full-suite run.

ApplicationIsolation failed before namespacing (`writer true`, `reader false`, exit 1), then passed
on both macOS and GTK. It checks distinct names with `main`, same-name reopening, and delimiter
collisions. The full live macOS desktop gate passes after this change (108 module assertions and
16 bridge tests). Independent architectural, implementation/API and forensic review found no
blockers in the application namespace, response slices, native regressions or GTK application CI.
The new CI job has been checked locally but remains unpublished. No current-delta CI result is
claimed, and the full compiler suite has not been rerun after the Linux continuation.

## Earlier next action (superseded)

Role transition: Tooling/Release owns actual Windows compiler build preparation in the task-owned
container, using the verified GHC9.14.1 bundle and pinned native SDK. Runtime Engineer owns no
further source changes until any resulting toolchain defect is documented in its mirror.

Prepare the native Windows Cabal executable and build the Pudu compiler with webview2 and the
same SDK/build flags as the prepared Windows application CI job; retain exact failure/success logs.
Preserve remaining runtime/network/selector conformance obligations and delivery partitioning.

## Referenced by

[[handoffs/_MOC]] · [[architecture/DESKTOP-WEBVIEW]]

Windows ownership extension: Runtime Engineer also owns native menu frame recalculation after replacement. Layout messages share geometry enforcement instead of menu-agnostic height hints.

## Windows geometry validation

Role transition: Architect resolves scoped COM callback creation; Runtime Engineer owns the
private host factory and its existing registration contract. Tooling/Release owns the dedicated
handler lifetime harness and CI registration. Captured resources expose creation-reference leaks
without requiring renderer startup; independent review follows focused validation.

The production Windows adapter, window, view and native units cross-compile and link with Clang
18, the Windows target headers and SDK 1.0.2903.40, using strict warnings. A scratch compatibility
header in the task container supplies case-sensitive SDK include/UUID declarations; it is not a
repository change or evidence of a completed Windows compiler build.

The resulting PE executable passes [[Webview Windows Window Harness]] under Wine 9 with a virtual
display/window manager. The test measures native client sizes and tracking bounds, both per-axis
resets, contradictory/overflow refusal, native maximize/restore, menu wrapping at narrow and wide
widths with active bounds, all four corner anchors, direct SetWindowPos, frame changes and
minimize/restore. Before fixes, wrapped menus reduced 320x240 to 320x114; a width change with active
limits produced 640x330 instead of 640x240. Both are now regression cases. Actual Windows CI is
still required; neither renderer execution under Wine nor Windows compiler application execution
has been proved. Logs are persisted beside earlier validation evidence.

Independent review cleared portable callable deduction, final COM concrete types and the corrected
geometry contract, including menu wrapping. A pre-existing callback creation-reference leak was
reproduced by [[Webview Windows Handler Harness]] (`failed registration leaked creation reference`,
exit 1). The factory now returns a movable, noncopyable owner; expression/scope cleanup releases
the creation reference while the consumer retains its own asynchronous reference. The real SDK
handler harness passes under Wine for rejection, synchronous invocation, retained completion,
QueryInterface release and moved ownership. All Windows production units rebuild and the native
geometry harness passes after the ownership change. Independent ownership and forensic review
found no remaining blockers in this bounded fix.

Additional persistent logs are `windows-build.log`, `windows-geometry.log`,
`windows-geometry-before.log`, `windows-wrapped-limits-before.log`, `windows-handlers.log` and
`windows-handlers-before.log`. These prove local cross-build/Wine behavior, not current Windows CI.
The former 745-line view unit is decomposed into view (355), environment (167) and request (211).
Shared host utilities live in the adapter (415). All Windows implementation units are below 500
lines. Thirteen moved helper bodies are unchanged; callback creation lifetime, deferred commands
and script readiness order are preserved. Both full adapter harnesses cross-build/link, and the
actual geometry executable passes under Wine. Independent implementation and forensic review
found no new blockers in the extraction. Current logs replace windows-build.log/windows-geometry.log.

Independent review identified an inherited policy defect. The actual Windows executable probe
prints `formatted-rule accepted=1 installed=0` and exits 1. Its log is windows-rules-probe.log.
The next correctness change must accept valid whitespace/key ordering, reject malformed/unsupported
rules transactionally, preserve the public producer's resource-type and if-domain conditions, and
apply hide-element rules only within their declared trigger scope. Do not claim full policy
conformance or hide this known failure behind the passing geometry/ownership harnesses.

Role transition: Architect resolves structural content rules from independent design review. Runtime Engineer owns the policy JSON header/implementation, Windows policy, request/view integration and host metadata. Tooling/Release owns parser/matcher/native action regressions and build registration. Preserve prior slices. Full cookie/network and renderer behavior remain separate required conformance evidence.

## Structural policy continuation

Forensic Guardian ownership includes the missing Std.Env mirror and Std MOC backlink, documenting
existing behavior without implementation changes.

[[Pudu Webview Policy JSON]] validates structural JSON, duplicate keys, UTF-8/surrogate escapes,
input/string/depth limits and complete consumption. [[Pudu Webview Windows Policy]] admits and
compiles whole lists transactionally, retaining URL/resource/main-document domain conditions.
Unsupported operators/categories refuse rather than approximate a wider rule. The public plugin
producer explicitly emits case-sensitive literal globs; the inspected fixture passes 108 checks.

Independent review found and cleared missing main-page identity, native/JS Unicode-domain mismatch,
pre-filter budget exhaustion and independent per-rule CSS budgets. Domain labels are canonical
ASCII/Punycode. Cheap applicability checks precede token costs; native requests share one work
budget, and all document CSS rules share one private closure/budget. Generated style guards use
compiled tokens, JSON-quoted selectors and browser top-origin identity for frame domain checks;
missing/redacted identity refuses domain-scoped modification. No dynamic backtracking regex remains.

Current evidence: portable JSON harness passes, full strict Windows cross-build passes, native
policy harness passes under Wine, emitted-script execution checks pass (including adversarial text,
frame domains and aggregate exhaustion), geometry harness still passes, and the full live macOS
desktop gate passes. Formatting/lint, workflow syntax, whitespace and new source-archive inclusion
checks pass. Source archives exclude private inputs. Independent implementation/architectural and
forensic review found no remaining blockers in this bounded parsing/matching/guard slice.

Remaining proof: actual cookie suppression after the network stack adds automatic cookies, native
upgrade behavior, real frame/navigation attribution and selector-failure reporting. Do not infer
these from pure matching or JavaScript VM tests. The empty Cookie override is an implementation
attempt whose actual effect must be verified. Current-delta Windows CI remains unpublished; PR #837
is open and currently not a draft, with 13,457 additions on its committed foundation. No local
continuation has been committed or pushed. Review-size partitioning remains a delivery obligation.

Logs in the existing persistent cache include windows-policy.log, windows-build.log,
windows-geometry.log, desktop-gate.log and sdist.log. The policy output includes emitted scripts for
independent execution, while its final marker is policy-rules=1. The historical failing probe remains
windows-rules-probe.log. The task container was restarted only after native inspection confirmed it
had exited; its installed compiler/SDK state was preserved.

Role transition: Architect resolves live policy evidence boundaries; Tooling/Release owns WebviewNetwork.c, desktop-policy-network.mjs and CI registration. Native adapter source remains unchanged while the real cookie/transport probes establish actual behavior.

## Live policy network evidence

Tooling/Release added a portable native harness and asynchronous loopback server gate. Real macOS
and GTK runs pass with ephemeral views: the server observes a fresh seeded cookie on the control,
no cookies on every protected POST, unchanged protected bodies and no blocked-endpoint arrivals.
Counters retain violations across retries. Monotonic/native and parent-process deadlines plus
child/connection cleanup bound failure paths. Independent implementation/forensic review found
no blockers; strengthening added ephemeral storage and all-arrival assertions without native changes.

The final Windows network executable cross-compiles and links against all production units. The
unpublished Windows CI step additionally requires a TLS ClientHello to the local listener and zero
original HTTP upgrade-endpoint arrivals. That probe is not successful HTTPS delivery or proof of
upgraded method/body preservation. macOS/GTK currently verify cookie/request blocking, with their
platform default-port upgrade semantics requiring a separate fixture. Native Windows execution,
response-cookie handling, successful HTTPS and selector-failure reporting remain open.

Persistent logs are macos-policy-network.log and linux-policy-network.log in the existing cache.
The Linux root-container sandbox exception remains test-only. No current-delta CI result, commit,
push or public completion claim is made.

Tooling/Release now owns response-cookie persistence and trusted-loopback HTTPS conformance extensions. TLS trust changes are limited to the task-owned Linux container and removed after each test; no host trust store is changed.

## Trusted HTTPS and cookie persistence

The response-cookie probe now uses a fresh cookie name per seed and an explicit ephemeral native
view. A protected response attempts Set-Cookie; a subsequent unprotected control must not carry it.
Real macOS and Linux runs pass, extending the previous outgoing-cookie evidence to storage behavior.

The isolated Linux HTTPS gate generates a one-day IP-SAN certificate in the task container, proves
it validates against the temporary aggregate trust store, runs native upgrade from HTTP80 to
HTTPS443 and removes only its temporary trust input afterward. The actual secure request preserves
path/query nonce, POST method and fresh body; the HTTP trap receives zero requests. It returns the
same data to the native page with ordinary certificate checking enabled. Final output reports
upgrade-delivery=1. No host keychain or host certificate store is modified.

Independent review found and cleared silent trust-rebuild cleanup errors and stale response-cookie
names. Cleanup completes all steps, preserves earlier errors, fails a successful run if trust
removal cannot be proved, and checks that the generated certificate no longer validates against
the rebuilt CA bundle. Failure injection forces the cleanup update command to fail, verifies the
wrapper fails, then restores the task trust store with an outer cleanup trap. A missing executable
failure also leaves no temporary trust/key directories. Final successful verification reports zero
remaining task certificates/directories. Shell/JavaScript syntax, workflow syntax, whitespace and
independent forensic/implementation re-review pass.

New persistent evidence: linux-policy-https.log and https-rehash-failure.log, alongside refreshed
macos-policy-network.log and linux-policy-network.log. Windows native runtime, actual native
selector-failure reporting, compiler application conformance and review-size delivery remain open.

Role transition: Architect resolves production Windows SDK metadata and C++ runtime selection. Runtime Engineer owns the SDK wrapper, host and interface-query callers; Tooling/Release owns GUID fixture, Cabal wiring and Windows compiler application CI. Preserve all preceding desktop work. Independent review follows focused validation.

## Production Windows SDK metadata

The original production-header path compiled but failed linking to undefined MinGW SDK UUID
helpers. [[Pudu Webview Windows SDK]] now preserves SDK metadata in a scoped include and defines
pudu_uuid while the compiler builtin is visible, then restores the caller macros. Native interface
queries use it. The SDK fixture compares three independent pinned-SDK GUID literals and macro
restoration; it passes under Wine. All Windows production units strict-build/link with no external
forced include or ignored-attribute suppression; handler ownership and geometry still pass.

Cabal now uses system-cxx-std-lib for the compiler runtime, enables native compiler extensions,
links uuid and includes the wrapper in source distributions. The new Windows application CI job
uses GHC9.14.1/Cabal3.16.1, native SDK1.0.2903.40, matching build/list-bin flags and loader placement.
It checks sequential App isolation and development Notes IPC, retaining logs. Independent review
found no blockers in the bounded SDK/runtime/CI wiring; actual Windows compiler application and
new CI execution remain unproved. Source-archive, syntax/whitespace and private-boundary checks pass.

Official Windows GHC9.14.1 archive download completed at 452323772 bytes and sha256sum reported OK
for 4914e262a91a9cb65807ec33b3a2adc884894b1dcc33691d820bb9456f2794ba.
The archive is /tmp/pudu-ghc-windows.tar.xz in the task container; extraction completed into
/tmp/pudu-ghc-windows/ghc-9.14.1-x86_64-unknown-mingw32. Its ghc.exe reports9.14.1 and bundled
clang.exe reports20.1.7 under Wine. Native compiler SDK/handler fixtures completed successfully, with WINEPATH set to the bundle's
mingw/bin. GHC's system-cxx-std-lib metadata selects :libc++.a and :libc++abi.a.
Persistent verification is win-ghc-download-verified.log, extraction output is win-ghc-extract.log,
version output is win-ghc-toolchain.log and fixture output is win-bundled-cxx.log.
Persistent SDK evidence is win-production-before.log, win-production-link-before.log,
win-production-build.log and win-production-geometry.log; sdk/handler markers were observed directly.
No local continuation has been committed, pushed or published.

Role transition: Architect resolves per-view callback lifetime admission. Runtime Engineer owns
pudu_webview_win.h, pudu_webview_win.cpp, pudu_webview_win_view.cpp and
pudu_webview_win_request.cpp; Tooling/Release owns WebviewWindow.cpp lifecycle regressions.
Independent review owns no implementation files. Preserve all existing work.

## Windows callback lifetime and reentrant teardown

All asynchronous view callbacks now require the captured lifetime token and numeric id. Retained
old tokens cannot authorize a replacement id. Stale environment completions emit no diagnostic;
a late borrowed controller is closed without releasing its borrowed reference. Script readiness,
eval, resource, navigation and page events use the same identity guard. Close while waiting for a
controller is immediate, and policy-failed views refuse later work except descriptor removal.

Independent review found and cleared native Close reentry defects: view and window registry owners
now detach into local ownership before teardown, all old views detach before the first controller
Close, and the old HWND loses userdata before native Close. Recreated view/window ids survive the
old teardown. Failure diagnostics capture identity before Close and callback diagnostics recheck
lifetime before publication.

The SDK controller double actually reenters close/create, verifies borrowed reference ownership,
checks retained-token replacement rejection and sends old-HWND size/move/activate messages after
creating a replacement window. Strict production Windows C++ compilation/linking passes; the
complete-adapter Wine harness reports callback-lifetime=1 and window-geometry=1. Handler ownership
and compiled-policy/generated-script gates pass. Changed mirror links and whitespace pass; all
owned source units remain below500 lines. Independent implementation and forensic re-review
reports no remaining blockers in this slice. Persistent output is win-callback-lifetime.log.

Native view COM-field resource ownership and unsupported ephemeral-mode fallback remain separate
open defects. Actual Windows compiler/application/runtime/network proof and delivery partitioning
remain required. No full current-delta compiler suite or CI execution is claimed. No continuation
commit, push or publication occurred.

## Verified bundled Windows C++ toolchain

The official GHC9.14.1 Windows archive's bundled Clang20.1.7 compiles and executes SDK UUID and
handler-ownership fixtures under Wine (sdk-uuid=1, handler-ownership=1). All production Windows
adapter units plus C records and the complete window/lifetime harness strict-compile and link
using this bundled compiler and runtime, without any forced include. GHC package metadata confirms
the boot C++ runtime selection matches the package manifest.

The first adapter run in the shared Wine prefix failed creating a window. Re-running the identical
binary in a fresh isolated Wine prefix under Xvfb/Openbox passes callback-lifetime=1 and
window-geometry=1. No source change was needed for this rerun; the failed attempt remains recorded.
Fresh prefix is /tmp/pudu-wine-bundled-window; keep it separate from headless compiler invocations.
The verified toolchain remains at /tmp/pudu-ghc-windows/ghc-9.14.1-x86_64-unknown-mingw32.

Persistent evidence: win-bundled-cxx.log, win-ghc-cxx-package.log, win-bundled-adapter.log (build and
initial failed run), and win-bundled-window.log (fresh-display successful run). All extraction/build
sessions from this slice have completed; no download or compiler process remains pending.
This is bundled native C++/SDK evidence under Wine, not actual Pudu compiler application execution
or Windows-host CI. Those remain open, alongside COM-field ownership and ephemeral fallback.

## Fail-closed storage admission and native record ownership

Role transition: Language Architect resolved the storage contract in the mirrors before source:
unnamed views are private on every adapter, only explicit labels share, Windows stores are
SHA-256 folders under a versioned namespace with an identity file, and admission refusals are a
typed `Refused` event that stops the application. Runtime Engineer owned the Windows environment,
profile, view, request and adapter units plus the macOS store selection. Standard Library Engineer
owned the `Refused` event and App handling. Tooling/Release owned the profile, ownership, window and
drive harnesses, the doubles header and CI/cabal registration. Independent review owns no files.

Delivered: [[Pudu Webview Windows Profile]] (new), fail-closed admission in
[[Pudu Webview Windows Environment]], refusal instead of crash for admission failures in
[[Pudu Webview Windows View]], view-bound pending records with exactly-once finishing in
[[Pudu Webview Windows Request]] and [[Pudu Webview Windows Adapter]], and private unnamed macOS
views in [[Pudu Webview macOS View]].

Evidence: all Windows units and harnesses cross-compile with `-Wall -Wextra -Werror` and run under
Wine with a virtual display: profile-admission=1, native-ownership=1, callback-lifetime=1 and
window-geometry=1. Reintroducing each original defect (private fallback, shared unnamed default,
latched realization, arbitrary response environment, unreleased close, unchecked deferral) makes a
harness fail. The macOS drive harness reproduced unnamed sharing (`private-isolation=0`) before the
change and passes after it. The rebuilt `-Werror` compiler passes the full live macOS desktop gate,
including 109 module checks, application isolation, window IPC and the Notes self-test. Logs:
win-slice-*.log, macos-private-isolation*.log, macos-slice-build.log and desktop-gate-slice.log.

Not proved: the doubles establish branch behavior only. Real Windows persisted-store reopen and
private/unnamed isolation on the actual runtime remain open, as do the Windows compiler application
build and current-delta Windows CI. Environments sharing one folder must have equal options, so two
views naming one store with different navigation allowlists will be refused rather than shared;
that limit is recorded in the profile mirror.

## Windows window controls

Role transition: Architect resolves Windows chrome/state parity with the macOS and GTK window
records; Runtime Engineer owns [[Pudu Webview Windows Control]] (new), the adapter's routing and
window procedure, and the host's window fields; Tooling/Release owns the window harness, its CI
registration and the Cabal stanza. Preserve every preceding slice.

The WebView2 adapter now answers every window record the other adapters answer; a transparent
title bar and badges refuse `Unsupported`, and `fullscreen` covers the monitor instead of
maximizing. [[Webview Windows Window Harness]] checks each record against the real window. No
Windows compiler is available on the macOS host that made this change, so the Windows build and
harness run only on the `windows-latest` job; the macOS desktop checks pass unchanged.

## Exact next action

Role transition: Tooling/Release owns real Windows storage evidence. Extend
[[Webview Drive Harness]] so the unnamed-isolation probe also runs on WebView2, add a two-run named
store reopen check, and run both on the `windows-latest` job with the real runtime.

Role transition: Architect resolves real storage conformance. Tooling/Release owns WebviewDrive.c,
a bounded WebviewStorage.c harness, desktop-storage.ps1 orchestration and desktop-webview.yml.
No adapter implementation changes belong to this slice. Independent review owns no source files.
The native Windows compiler attempt terminated at time1.14 configure because this Wine environment
has no compatible sh.exe; it is not a successful full compiler build.

## Published continuation and CI repair

Architect → Runtime Engineer → Tooling/Release. This follow-up owns [[Eval Stop Requests]],
[[Webview Storage Harness]], [[Webview Windows Storage Probe]], [[Desktop Storage Gate]],
their mirrors, the evaluator map, changelog and this handoff.

The continuation is published in #837. The enabled compiler build reported an unused
platform-specific import. The live storage write passed but global browser enumeration
failed on a process with unreadable metadata. The harness now verifies exit using handles
obtained from the actual views, and the application build uses only imports available to its
selected platform branch.

Exact next action: verify the storage reopen and compiler application jobs on #837.
