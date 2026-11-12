---
type: module
path: "@root/test/native/WebviewPolicyJson.cpp"
fidelity: Active
aliases: [Webview Policy JSON Harness]
tags: [module, test, desktop, policy]
---
# Webview Policy JSON Harness

## Purpose and interface

Exercise structural JSON parsing with formatted/reordered values, duplicate keys, malformed UTF-8 and escapes, paired/unpaired surrogates, control characters, numbers, depth/string/input bounds, atomic output and safe text quoting. This portable harness runs without a native renderer.

## Grill Log

- **Q:** Can a passing parse test prove native network effects? **A:** No. Parsing, matching, generated scripts and actual renderer/network behavior have separate evidence.
- **Q:** What makes refusal transactional? **A:** Failed lists leave existing rules untouched, including when a valid prefix preceded the invalid entry.

## Dependencies and consumers

Uses [[Pudu Webview Policy JSON]] and [[Pudu Webview Windows Policy]]. Run by [[Desktop Webview CI]].

## Referenced by

[[src/_MOC]] · [[Desktop Webview CI]] · [[Pudu Webview Windows Policy]]
