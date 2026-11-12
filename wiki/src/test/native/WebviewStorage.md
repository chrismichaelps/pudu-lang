---
type: module
path: "@root/test/native/WebviewStorage.c"
fidelity: Active
aliases: [Webview Storage Harness]
tags: [module, test, desktop, isolation]
---
# Webview Storage Harness

## Purpose and interface

Run `storage write <hex nonce>` followed by `storage read <same nonce>` as distinct processes
against the same real adapter. A fresh explicit store label derives from the validated nonce.
The write run asserts a fresh named store, writes the nonce and verifies its own readback. A view
requesting ephemeral storage with that same label and an unnamed view must each see empty storage
before writing a private marker. The read run requires the named nonce to persist while
both private views start empty; a different explicit label also starts empty. On Windows,
[[Webview Windows Storage Probe]] verifies the actual native private-mode flags and reopens each
old private profile as persistent. Neither old profile may contain its prior marker; this defeats
false passes from changing private profile names.

## Failure and lifecycle

Every page reports a unique success title after checking synchronous localStorage results. A
JavaScript exception, native admission refusal, crash, malformed event, allocation failure or
monotonic deadline failure fails the process. Close through the ABI on success and failure.
Never accept a generic loaded/title event as storage evidence. Nonces must be exactly32 lowercase
hexadecimal characters, so generated page source cannot contain caller-injected syntax.

## Grill Log

- **Q:** Why two processes? **A:** Recreating a view in one process cannot establish cross-process
  named persistence or private-data reset. Each phase captures its views’ browser process handles before closing the window.
  [[Webview Windows Storage Probe]] waits for those handles before the phase reports success.
- **Q:** Why write private markers? **A:** Empty-only probes miss persistence leaks. Reopening
  both modes must be empty despite previously completed private writes.
- **Q:** Do doubles prove this? **A:** No. The harness links the production adapter and requires
  actual renderer pages to observe storage values.

## Dependencies and consumers

Uses [[Pudu Webview Header]] and [[Pudu Webview Records]]. Run by [[Desktop Storage Gate]] and
[[Desktop Webview CI]]; complements [[Webview Drive Harness]] and [[Webview Windows Profile Harness]].

## Referenced by

[[src/_MOC]] · [[Desktop Storage Gate]] · [[Desktop Webview CI]] · [[Webview Drive Harness]]
