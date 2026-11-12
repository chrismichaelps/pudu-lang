---
type: module
path: "@root/test/native/WebviewPolicy.cpp"
fidelity: Active
aliases: [Webview Windows Policy Harness]
tags: [module, test, desktop, policy]
---
# Webview Windows Policy Harness

## Purpose and interface

Exercise complete rule installation with the actual private Windows policy API: whitespace/key order, schema/type/unknown-field failures, invalid Unicode, transactional failure after a valid prefix, explicit native resource mapping, URL/domain conjunction and wildcard boundary attacks, case modes and literal/authority filter tokens. Emit guarded normal and adversarial-selector CSS source for independent JavaScript execution checks. No cookie/network effect is claimed from parser tests.

## Grill Log

- **Q:** Can a passing parse test prove native network effects? **A:** No. Parsing, matching, generated scripts and actual renderer/network behavior have separate evidence.
- **Q:** What makes refusal transactional? **A:** Failed lists leave existing rules untouched, including when a valid prefix preceded the invalid entry.

## Dependencies and consumers

Uses [[Pudu Webview Policy JSON]] and [[Pudu Webview Windows Policy]]. Run by [[Desktop Webview CI]].

## Referenced by

[[src/_MOC]] · [[Desktop Webview CI]] · [[Pudu Webview Windows Policy]]

Resolved Grill Log: inject failed/null main-document metadata with domain policies. Verify that only an exact pending top-document URI can substitute trusted identity, never a frame/unrelated request.

Resolved Grill Log: assert deterministic work exhaustion with long patterns/URLs and a shared depleted budget, plus rejection of Kelvin-sign/Unicode and malformed domain labels before native/script scopes can diverge.

Resolved Grill Log: long excluded resource/domain rules must return NoMatch without reserving full URL work. Emit several individually bounded CSS rules whose aggregate exceeds the shared document budget.
