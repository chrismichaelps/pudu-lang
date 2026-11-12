---
type: module
path: "@root/cbits/pudu_webview_policy_json.h"
fidelity: Active
aliases: [Pudu Webview Policy JSON Header]
tags: [module, runtime, desktop, policy]
---
# Pudu Webview Policy JSON Header

## Purpose and interface

Portable structural JSON values (text, boolean, array, object and other scalars), a bounded parse entry returning an offset-bearing error, and safe JSON string quoting. These private interfaces serve Windows policy parsing and eval decoding.

## Semantics

Reject duplicate object keys, invalid UTF-8 and escapes, unpaired surrogate escapes, trailing input, more than sixteen nested containers and input above 1 MiB; strings are bounded to 64 KiB. Generic JSON preserves escaped NUL; native policy schema refuses it before use.

## Grill Log

- **Q:** May a declared condition be ignored for compatibility? **A:** No. Refuse the complete list when a condition cannot be represented; never install a broader policy.
- **Q:** Can a valid prefix survive a failed installation? **A:** No. Parsing and compilation commit only after every entry succeeds.
- **Q:** How is hostile input bounded? **A:** Input/string/container limits and nonrecursive filter matching prevent parser recursion or backtracking from becoming unbounded.

## Dependencies and consumers

Uses [[Pudu Webview Windows Host]] where native metadata is required. Consumed by [[Pudu Webview Windows Request]], [[Pudu Webview Windows View]] and policy conformance tests; registered by [[Pudu Cabal Manifest]] and [[Desktop Webview CI]].

## Referenced by

[[src/cbits/_MOC]] · [[Pudu Webview Windows Request]] · [[Pudu Webview Windows Host]]
