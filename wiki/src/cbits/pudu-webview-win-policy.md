---
type: module
path: "@root/cbits/pudu_webview_win_policy.cpp"
fidelity: Active
aliases: [Pudu Webview Windows Policy]
tags: [module, runtime, desktop, policy]
---
# Pudu Webview Windows Policy

## Purpose and interface

Validate and compile complete content-rule lists transactionally, match every declared URL/resource/main-document-domain condition, and generate guarded hide-element scripts.

## Semantics

Root is an array of at most 4096 entries with exactly trigger/action. Trigger requires url-filter and admits optional resource-type, if-domain and url-filter-is-case-sensitive. Actions are block, block-cookies, make-https or css-display-none, with selector only for hiding. Unknown/duplicate/wrong fields are Malformed; unrepresentable categories/filter constructs are Unsupported. Native-bound strings reject NUL. Compile a temporary list before appending to existing rules. URL filters use a nonrecursive token matcher for literal text, escaped literals, anchors, .* and the producer authority wildcard [^/?#@]*; unsupported regex operators refuse. Matching defaults insensitive unless explicitly configured. Domain conditions use the main document host with exact or wildcard domain-boundary matching. Resource categories map explicitly to native contexts; unsupported categories refuse the whole list. CSS guards the actual document URL/domain and admits only document-compatible scopes. Cookie suppression stays unproved until seeded-cookie network conformance passes; a header mutation alone is insufficient evidence.

## Grill Log

- **Q:** May a declared condition be ignored for compatibility? **A:** No. Refuse the complete list when a condition cannot be represented; never install a broader policy.
- **Q:** Can a valid prefix survive a failed installation? **A:** No. Parsing and compilation commit only after every entry succeeds.
- **Q:** How is hostile input bounded? **A:** Input/string/container limits and nonrecursive filter matching prevent parser recursion or backtracking from becoming unbounded.

## Dependencies and consumers

Uses [[Pudu Webview Windows Host]] where native metadata is required. Consumed by [[Pudu Webview Windows Request]], [[Pudu Webview Windows View]] and policy conformance tests; registered by [[Pudu Cabal Manifest]] and [[Desktop Webview CI]].

## Referenced by

[[src/cbits/_MOC]] · [[Pudu Webview Windows Request]] · [[Pudu Webview Windows Host]]

Resolved Grill Log: one request shares a 1,048,576-unit evaluation budget across its rule list. Charge a conservative token/string-work upper bound before matching; exhaustion is a distinct result and closes/blocks the protected request. Generated CSS uses the same token evaluator and a bounded work check, never a dynamically compiled backtracking expression. Admit only canonical lower-ASCII/Punycode DNS labels (including bounded label lengths); reject raw Unicode and malformed domain labels transactionally. ASCII-only case folding is explicit; non-ASCII insensitive URL filters are Unsupported.

Resolved Grill Log: cheap resource/domain predicates are budgeted and evaluated before URL token work; excluded long filters cannot exhaust URL budget. All hide-element rules compile into one closure with one private per-document budget. Frame rules use their own URL and the browser-provided top ancestor origin for domain scope, with same-origin top-location fallback; unavailable/redacted ancestor identity refuses domain-scoped CSS explicitly. Browser Location ancestor origins are read-only; actual backend frame conformance remains required.
