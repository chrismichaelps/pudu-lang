---
type: module
path: "@root/cbits/pudu_webview_win_environment.cpp"
fidelity: Active
aliases: [Pudu Webview Windows Environment]
tags: [module, runtime, desktop, windows]
---
# Pudu Webview Windows Environment

## Purpose and interface

Own the native environment options, secure Pudu scheme registration, allowed calling origins,
the dynamic loader and controller admission. `pudu_environment(view, completion)` loads the
runtime, resolves storage through [[Pudu Webview Windows Profile]], marks the view realizing and
requests its environment with the provided scoped completion. `pudu_admit_controller(view,
environment, hwnd, completion)` requests the controller with the view's storage mode.
`pudu_realization_refused(view, status, reason)` closes a view whose admission failed and reports it.

## Semantics

`pudu_environment` returns Unsupported for a missing loader, the profile's Platform refusal for
missing or truncated native paths, and Platform when the native call rejects creation. None of
these leaves the view realizing: a rejected creation also replaces the view's lifetime token, so
a stray completion from that attempt cannot admit a later retry. Done means the native call
accepted creation and the view stays realizing until its controller arrives or it closes.

A private view (ephemeral or unnamed) requires every step of private admission: the options
interface, non-null controller options, a distinct profile name, enabling private mode, reading
it back as enabled, and the controller request itself. A missing interface refuses with
Unsupported; any other failed step refuses with Platform. Ordinary controller creation is never
used for a private view. A named view uses ordinary creation in its verified store folder, and a
rejected request refuses with Platform. A refusal closes the descriptor to further realization,
emits `refused <view> <unsupported|platform> <reason>` and leaves only descriptor removal.

Configuration COM objects keep reference-counted ownership. The caller owns the completion's
creation reference; the native consumer retains its own. Options and controller options are
released after their native calls on success and failure. Controller wiring remains in
[[Pudu Webview Windows View]].

## Grill Log

- **Q:** Why a separate environment unit? **A:** Loader/profile/scheme configuration precedes
  controller registration and resource routing. Keeping it together bounds platform configuration
  changes without expanding the view command/lifecycle module.
- **Q:** Should extraction change the profile scheme? **A:** No. This move preserves existing
  behavior; isolation/profile upgrades require their own explicit contract and regressions.
- **Q:** Why is a failed private step a refusal and not a fallback? **A:** Ordinary creation
  writes to disk. A view that asked to keep nothing must never become persistent, so the only
  safe outcomes are a confirmed private controller or a closed view with a typed reason.
- **Q:** Is a synchronous creation failure terminal? **A:** No. Nothing native is outstanding, so
  the view returns to configurable and may realize again; the replaced lifetime token keeps the
  rejected attempt from completing into the retry.
- **Q:** Can configuration COM objects be subclassed? **A:** No. Final concrete types own their
  reference-counted self-deletion; a nonvirtual COM destructor must not lose derived state.

## Dependencies and consumers

Uses [[Pudu Webview Windows Host]] and [[Pudu Webview Windows Profile]]. Called by [[Pudu Webview Windows View]]. Registered in
[[Pudu Cabal Manifest]] and linked by [[Desktop Webview CI]].

## Referenced by

[[src/cbits/_MOC]] · [[Pudu Webview Windows View]] · [[Pudu Webview Windows Host]] ·
[[Pudu Webview Windows Profile]] · [[Webview Windows Profile Harness]]

Resolved Grill Log: COM interface identity queries use the production SDK UUID helper, preserving the same declared native identifiers on Microsoft and Clang toolchains.
