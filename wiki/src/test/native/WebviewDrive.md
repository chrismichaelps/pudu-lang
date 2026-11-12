---
type: module
path: "@root/test/native/WebviewDrive.c"
fidelity: Active
aliases: [Webview GTK Harness, Webview Drive Harness]
tags: [module, test, desktop, webview]
---
# Webview Drive Harness

Drives whichever adapter it is linked with through the six entry points: opens a window with a
filling view and a second view at a fixed frame (which must report its own title), the first that injects a script and posts `ping` to the `pudu` scheme, answers `pong`, waits for the page
title, evaluates `document.title` with the injected value and requires `done:pong:42`, then
navigates outside the allowlist and requires `navigation-blocked`. A content rule blocks a fetch of
`pudu://app/blocked` before it reaches the program, and the page reports the refusal in its call,
which also shows the page loaded only after the rule list compiled. On every platform it also installs a
menu bar and requires a native surface to accept a frame of its size, refuse one of another size,
and close. CI links it with the macOS
adapter and with the WebKitGTK adapter under a virtual display.

## Referenced by

[[Desktop Webview CI]] · [[Pudu Webview macOS Adapter]] · [[Pudu Webview GTK Adapter]]

Resolved Grill Log: on macOS validate extra window commands and reported state, malformed native
flags/titlebar/color arguments and disabled inspector refusal before closing the window.

Resolved Grill Log: a configured inspector is toggled on and off when the platform exposes it; unsupported programmatic opening is reported explicitly.

Resolved Grill Log: Linux window state, malformed flags/colors/styles and disabled inspector refusals share the existing native checks. Native controls are exercised through the record channel, and unavailable desktop-specific operations remain explicit.

Resolved Grill Log: GTK authenticated messages are driven from real pages with missing, wrong and valid keys/origins; only granted requests may change maximize state. An X11 window manager supplies real state transitions under the virtual display.

Resolved Grill Log: Linux grow/shrink assertions wait for reported content sizes, catching implicit minimum-size feedback from fill views.

Resolved Grill Log: an unnamed view cannot observe another unnamed view's local storage. A named shared-context pair retains independent request-view identity.

Resolved Grill Log: after native initialization, a worker thread must receive NotMainThread from both send and respond.

Resolved Grill Log: start named-store clearing, close both users and immediately reopen the label; verify native context identity is unchanged and the real clear completion retains its two-field contract.

Resolved Grill Log: exercise visible, transparent and overlay titlebars after realization, and verify overlay controls align with the view while remaining below the native menu.

Resolved Grill Log: the real ping request completes with NULL/zero headers; malformed NULL/positive response slices are rejected independently of request identity.

Resolved Grill Log: shared-storage assertions use a fresh nonce, preventing persisted data from satisfying the check. UI waits use monotonic deadlines because a pump can return immediately for queued events. Cross-view storage propagation is observed with bounded reads. Failed probes retain the last title and evaluation error.

Resolved Grill Log: the unnamed-view isolation probe also runs against the macOS adapter and
prints `private-isolation`. Its title helper uses a portable monotonic clock and is built only on
the two platforms that run it. Before unnamed macOS views received their own non-persistent
store, the probe reported `private-isolation=0`; it now reports 1.

Resolved Grill Log: compile the monotonic title probe on Windows using GetTickCount64 and run the
same unnamed-view localStorage separation check there. The general drive harness remains below
500 lines; cross-process persistent storage belongs to [[Webview Storage Harness]].
