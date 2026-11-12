---
type: module
path: "@root/cbits/pudu_webview_policy_json.cpp"
fidelity: Active
aliases: [Pudu Webview Policy JSON]
tags: [module, runtime, desktop, policy]
---
# Pudu Webview Policy JSON

## Purpose and interface

Decode bounded JSON structurally with validated Unicode and duplicate-key detection; quote text for generated JavaScript using JSON literals.

## Semantics

Parsing returns a fresh value only on complete success. Error offsets identify malformed syntax. Array/object recursion is explicitly bounded; no exception-driven numeric conversion or substring field search. Numbers/null remain distinct non-schema scalar values.

## Grill Log

- **Q:** May a declared condition be ignored for compatibility? **A:** No. Refuse the complete list when a condition cannot be represented; never install a broader policy.
- **Q:** Can a valid prefix survive a failed installation? **A:** No. Parsing and compilation commit only after every entry succeeds.
- **Q:** How is hostile input bounded? **A:** Input/string/container limits and nonrecursive filter matching prevent parser recursion or backtracking from becoming unbounded.

## Dependencies and consumers

Uses [[Pudu Webview Windows Host]] where native metadata is required. Consumed by [[Pudu Webview Windows Request]], [[Pudu Webview Windows View]] and policy conformance tests; registered by [[Pudu Cabal Manifest]] and [[Desktop Webview CI]].

## Referenced by

[[src/cbits/_MOC]] · [[Pudu Webview Windows Request]] · [[Pudu Webview Windows Host]]
