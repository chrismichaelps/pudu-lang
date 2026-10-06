---
type: module
path: "@root/website/src/App/Static.pudu"
fidelity: Active
tags: [website, application, mediator]
aliases: [website App Static]
---
# Website App Static

The complete site's application: [[website Site]], the mediator built over it once, its kinds, and its
logger. `assemble` registers [[website App Pipeline]], [[website App Playground]], and one handler per
page kind, each calling the same service and view the router used to call directly; a build problem is
answered as `ApplicationInvalid` and stops startup. [[website Main]], [[website Platform Render]],
[[website Prerender]], and the suites serve this value through [[website Web Routes]].

Resolved Grill Log: handlers close over the site they were built with, so a suite that serves two
sites builds two applications. _Rejected:_ reading the site from the message context (a lookup that
can miss, on every message).
