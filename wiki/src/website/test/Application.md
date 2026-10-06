---
type: module
path: "@root/website/src/Test/Application.pudu"
fidelity: Active
tags: [website, tests, application]
aliases: [website application suite]
---
# Website Application Suite

Checks the application layer over the default site: a search at its 512-character limit is answered
and one over it is a no-index `400` naming the field without echoing the value; an oversized filter or
module name is refused; a pasted suggestion within the hard limit is answered and an absurd one
refused; a message sent straight to the mediator is refused the same way. Pages keep their answers:
home, a missing page, an unknown package filter, page zero, and the listing's own first address.
Every request writes one access event naming method, path, and status, graded information, warning,
or error, never with its query string; a playground run is audited without the reader's address. The
function's application refuses oversized search, serves a listing page not yet published with the
short missing-package cache, and answers six kinds where the site answers eleven. Failure translation
covers missing, unavailable, invalid, and faults, and `isFault` tells faults from answers. Finally it
starts [[website Platform Render]] with three wrong settings and requires all of them in one refusal.

Resolved Grill Log: settings are tested through a real start because a program cannot set its own
environment; the renderer stops before loading anything, so the check is fast.
