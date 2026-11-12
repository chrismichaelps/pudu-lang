---
type: module
path: "@root/cbits/pudu_webview_win.h"
fidelity: Active
tags: [module, runtime, desktop, webview, windows]
aliases: [Pudu Webview Windows Host]
---

# Pudu Webview Windows Host

The Windows adapter's private declarations: `PuduHandler`, one COM object template that forwards
`Invoke` to a function for every WebView2 completion and event interface; the window, view, pending
request and rule records; the process-wide host; and the helpers both translation units share
(events, UTF-8/UTF-16 conversion, refusal, fitting views).

Window owners retain independent per-axis minimum and maximum client dimensions, with zero meaning
unbounded. Geometry helpers are declared here and implemented by [[Pudu Webview Windows Window]].

## Grill Log

- **Q:** Why one template instead of a class per handler? **A:** WebView2 has a dozen handler
  interfaces that differ only in `Invoke`'s parameters; a template with those parameters as its
  arguments keeps each registration beside the code it runs.
- **Q:** Where do native limits live? **A:** In the window owner, so commands and WM_GETMINMAXINFO
  retain the same bounds without relying on application resize callbacks.
- **Q:** Should handler factories deduce through std::function? **A:** No. Accept the callable
  directly, then explicitly construct the declared COM signature; standard template deduction
  does not convert a lambda to std::function. The reference-counted handler is final so deletion
  through its concrete type cannot discard derived state.

## Scoped callback creation

Resolved Grill Log: expose environment creation and request-policy helpers through this private
header. Native inline-page origin is one shared constant. View lookup, COM string release and
numeric view labels are shared utilities implemented in the adapter; no public ABI changes.

Resolved Grill Log: `pudu_handler` returns a movable, noncopyable owner that converts to the
declared interface pointer for registration. It retains reference count one until expression or
named-owner scope end, then releases it on success and failure. Native consumers retain their own
references for asynchronous use. Never use initial count zero or transfer ownership by omission.
[[Webview Windows Handler Harness]] observes captured-resource destruction on every lifecycle path.

Resolved Grill Log: owners guard recursive layout; shared sizing/position helpers apply width-aware constraints.

## Referenced by

[[Pudu Webview Windows Adapter]] · [[Pudu Webview Windows View]] · [[Pudu Webview Windows Window]] · [[Webview Windows Handler Harness]]

Resolved Grill Log: PuduRule retains compiled filter tokens, case mode, resource categories and main-document domains. The private policy entry returns a typed native status plus rule/field diagnostic; matching receives resource context and main-page URL.

Resolved Grill Log: retain the accepted top-level navigation URL separately from frame navigation. Resource matching uses the current native top-page source, with the accepted pending URL for the top-document request itself.

Resolved Grill Log: declare a metadata admission helper receiving native source HRESULT and the observed page; domain-scoped policies refuse absent source identity except the exact pending top-document request.

Resolved Grill Log: matcher returns Match/NoMatch/Exhausted and takes the shared remaining evaluation budget. Domain labels are canonical ASCII, and CSS receives the identical compiled token sequence.

Resolved Grill Log: expose one whole-list style-policy source generator instead of per-rule closures.

Resolved Grill Log: include [[Pudu Webview Windows SDK]] and use its scoped UUID helper for all COM interface queries. No forced test header or global UUID macro change is required.

Resolved Grill Log: every native view owns a noncopyable lifetime token; callbacks capture a weak
reference plus numeric id. Lookup requires the same live token, even if an old token remains held.
Closing invalidates before native Close, including protected-request fatal shutdown. Private
controller/environment callback factories expose the actual delayed-completion seam to tests.
A stale controller completion closes its borrowed controller without releasing its borrowed reference.

## Owned native records

Resolved Grill Log: a pending request record carries its originating view id, a weak reference
to that view's lifetime token and its own counted environment reference, alongside the counted
event arguments and deferral. Exactly one finishing path releases the arguments, deferral and
environment: either the program's response, or the close of the originating view, which detaches
its records before native teardown. Profile, admission, refusal and abandonment helpers are
declared here for the environment, view, request and adapter units.

Resolved Grill Log: a window also keeps its requested chrome flags, fullscreen placement, owned
background brush and last reported state for [[Pudu Webview Windows Control]].
