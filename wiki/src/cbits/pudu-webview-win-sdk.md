---
type: module
path: "@root/cbits/pudu_webview_win_sdk.h"
fidelity: Active
aliases: [Pudu Webview Windows SDK]
tags: [module, runtime, desktop, windows, interop]
---
# Pudu Webview Windows SDK

## Purpose and interface

Include native SDK interfaces with their COM UUID metadata intact for the supported Windows C++
compilers. `pudu_uuid<Interface>()` returns the SDK-declared interface identifier. The private wrapper
bridges Clang/MinGW headers that otherwise erase MIDL UUID annotations; the Microsoft compiler path
uses its existing declarations unchanged. No interface UUIDs are invented or generated from names.

## Semantics

Temporarily preserve UUID attributes while loading SDK declarations under Clang/MinGW. Define the
private UUID helper while the compiler builtin is visible, then restore the caller's MIDL_INTERFACE
and __uuidof macros. All Pudu SDK queries use the helper, avoiding a leaking preprocessor override.
The package enables Microsoft extensions for the bundled Windows Clang toolchain and selects its
C++ runtime through the compiler's system-cxx-std-lib package instead of assuming GNU's runtime.

## Grill Log

- **Q:** Why not ship the local forced-include workaround? **A:** SDK metadata is a production build
  requirement. Scope the adaptation to one private header, restore macros and verify known SDK IDs.
- **Q:** Can the helper compare against itself to prove correctness? **A:** No. The SDK harness checks
  independent stable interface GUID literals declared by the pinned SDK.
- **Q:** Is this an ABI change? **A:** No. Interface identifiers and the six C entry points are unchanged.

## Dependencies and consumers

Uses native Windows and SDK declarations. Included by [[Pudu Webview Windows Host]], tested by
[[Webview Windows SDK Harness]], and shipped by [[Pudu Cabal Manifest]].

## Referenced by

[[src/cbits/_MOC]] · [[Pudu Webview Windows Host]] · [[Desktop Webview CI]]

## Verification evidence

The verified official GHC9.14.1 Windows bundle includes Clang20.1.7. Its actual compiler passes the
independent SDK GUID and handler-ownership fixtures, and builds/links the full production adapter
and lifecycle/geometry harness. That harness passes in an isolated Wine display prefix. The boot
system-cxx-std-lib package declares libc++ and libc++abi. Actual Pudu compiler application builds
and Windows-host execution remain separate requirements.
