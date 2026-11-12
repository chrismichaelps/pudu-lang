---
type: module
path: "@root/cbits/pudu_webview_win_request.cpp"
fidelity: Active
aliases: [Pudu Webview Windows Request]
tags: [module, runtime, desktop, windows, policy]
---
# Pudu Webview Windows Request

## Purpose and interface

Own navigation admission, content-rule parsing/enforcement, injected-style construction, native
request collection and local responses. Private interfaces expose rule parsing, JSON string
extraction, style construction and resource/navigation callbacks to [[Pudu Webview Windows View]].

## Semantics

Preserve the existing allowlist and content-rule ordering. Local inline pages and blocked requests
are answered before creating a program request. Other Pudu requests retain their body, headers,
source page and native deferral in the process host until answered. Navigation and frame navigation
use the same admission function and report refused targets. JSON/rule parsing behavior remains
unchanged in this extraction; no stronger parser guarantees are claimed.

The earlier substring parser accepted formatted JSON while installing zero rules. Structural
parsing and transactional compiled admission now replace it; the formatted rule regression passes.
Native resource/domain metadata and every declared condition remain part of matching. Actual
cookie/network effects and native selector-failure reporting remain unproved.

## Grill Log

- **Q:** Why group policy with requests? **A:** Rule enforcement and local answers decide whether
  requests enter the program at all. Their shared parsing and response contracts belong together.
- **Q:** Is moving a static helper a semantic change? **A:** Its private linkage changes only where
  another translation unit consumes it; preserve the body and registration order exactly.

## Dependencies and consumers

Uses [[Pudu Webview Windows Host]] and [[Pudu Webview Records]]. Called by
[[Pudu Webview Windows View]], registered in [[Pudu Cabal Manifest]] and [[Desktop Webview CI]].

## Referenced by

[[src/cbits/_MOC]] · [[Pudu Webview Windows View]] · [[Pudu Webview Windows Host]]

Resolved Grill Log: replace substring rule parsing with [[Pudu Webview Windows Policy]] and [[Pudu Webview Policy JSON]]. Resource callbacks collect ResourceContext and the main-page URL before matching. Preserve every declared trigger condition; failure must not widen policy.

Resolved Grill Log: resource metadata includes its native context and current top-document source. Accepted top-level navigation updates a pending page URL; frame navigation never overwrites it. Upgrades mutate the native URI and fail closed on error; cookie overrides also check native HRESULT, while actual automatic-cookie suppression remains a required live network test.

Resolved Grill Log: protected native failures produce a checked blocked response. If even that response cannot be created/applied, close the controller and report a failed rule event; never silently resume the protected request. Inline HTML also requires checked stream/response construction.

Resolved Grill Log: every request, including an inline application document, passes declared rules before a local answer is constructed. Local asset handling cannot bypass policy.

Resolved Grill Log: if a domain-scoped rule exists, a failed/null/empty main-page source is a protected metadata failure. A matching accepted top-document request may substitute its pending URL; a frame or unrelated resource may not. Expose the pure metadata admission seam for failure injection.

Resolved Grill Log: share the policy work budget across all rules for a request; exhaustion emits a rule-failure event and blocks before network dispatch.

Resolved Grill Log: missing request/URI metadata and unknown resource contexts are protected failures when policies exist; they cannot bypass URL or resource predicates.

Resolved Grill Log: navigation receives a lifetime reference and cancels stale requests without
publishing an event against a reused id. Fatal protected-response failure invalidates callbacks
before controller Close; the diagnostic is emitted once by the failure path itself.

Resolved Grill Log: erase registry membership while moving ownership into a local owner before
native teardown. Reentrant close/recreate must not invalidate an active iterator, delete the
teardown owner, or erase a replacement id. Capture failure diagnostic labels before native Close
and recheck callback identity before later publication when the descriptor may be replaced.

Resolved Grill Log: a Pudu request is published only after its deferral is acquired. A failed
deferral, a null deferral, or a view without an environment answers the request synchronously
with 503, publishes nothing and keeps no references, so a later response cannot reach a missing
deferral. The method and source page are read only after admission. Records bind the view's
lifetime and environment; `pudu_finish_request` completes and releases one record, and
`pudu_abandon_requests` detaches every record of a closing lifetime before finishing any.
