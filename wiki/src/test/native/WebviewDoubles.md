---
type: module
path: "@root/test/native/WebviewDoubles.h"
fidelity: Active
aliases: [Webview Windows Doubles]
tags: [module, test, desktop, windows]
---
# Webview Windows Doubles

## Purpose and interface

Counted WebView2 doubles shared by the profile and ownership harnesses: an environment exposing
the private-options interface on request, controller options, a controller and renderer pair,
resource event arguments, a deferral, a request and a response. Each double counts references
and the calls under test, and lets a case choose the result of each native step.

## Semantics

Doubles never delete themselves; the harness owns them on its stack and compares counts. Methods
outside the cases answer `E_NOTIMPL`. A double's `QueryInterface` returns only interfaces the case
enabled, so a missing interface is a real `E_NOINTERFACE`.

## Grill Log

- **Q:** Why a shared header? **A:** Both harnesses need the same environment and request doubles;
  one definition keeps their failure switches identical.

## Dependencies and consumers

Uses [[Pudu Webview Windows SDK]]. Used by [[Webview Windows Profile Harness]] and
[[Webview Windows Ownership Harness]].

## Referenced by

[[src/_MOC]] · [[Webview Windows Profile Harness]] · [[Webview Windows Ownership Harness]]
