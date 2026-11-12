---
type: module
path: "@root/test/desktop-policy.mjs"
fidelity: Active
aliases: [Desktop Policy Script Gate]
tags: [module, test, desktop, policy]
---
# Desktop Policy Script Gate

## Purpose and interface

Run the Windows policy harness, then evaluate its emitted style scripts in isolated JavaScript contexts. Matching and nonmatching page/domain cases test actual generated control flow; selector text must stay data, with no source injection. This does not replace native DOM/network conformance.

## Grill Log

- **Q:** Can a passing parse test prove native network effects? **A:** No. Parsing, matching, generated scripts and actual renderer/network behavior have separate evidence.
- **Q:** What makes refusal transactional? **A:** Failed lists leave existing rules untouched, including when a valid prefix preceded the invalid entry.

## Dependencies and consumers

Uses [[Pudu Webview Policy JSON]] and [[Pudu Webview Windows Policy]]. Run by [[Desktop Webview CI]].

## Referenced by

[[src/_MOC]] · [[Desktop Webview CI]] · [[Pudu Webview Windows Policy]]

Resolved Grill Log: test shared CSS exhaustion, matching/nonmatching frame top domains and refusal when top-domain metadata is unavailable. Native browser conformance is still separate evidence.
