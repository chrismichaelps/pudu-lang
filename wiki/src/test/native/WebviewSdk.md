---
type: module
path: "@root/test/native/WebviewSdk.cpp"
fidelity: Active
aliases: [Webview Windows SDK Harness]
tags: [module, test, windows, interop]
---
# Webview Windows SDK Harness

## Purpose and interface

Compile and run the production SDK wrapper with no forced compatibility include. Compare callback,
environment-option and settings UUIDs against independent literals from SDK 1.0.2903.40. Verify the
wrapper restores caller macros and produces distinct identifiers. A failed comparison exits one.
The standard handler ownership harness also uses the production UUID helper.

## Grill Log

- **Q:** Can syntax success prove UUID support? **A:** No. The original path compiled yet linked to
  undefined MinGW UUID helpers. Link and run the fixture, then link the production adapter too.
- **Q:** Does a cross-build prove the Windows compiler application? **A:** No. Actual compiler and
  page execution remain separate conformance checks.

## Dependencies and consumers

Uses [[Pudu Webview Windows SDK]]. Run by [[Desktop Webview CI]].

## Referenced by

[[src/_MOC]] · [[Desktop Webview CI]] · [[Pudu Webview Windows SDK]]
