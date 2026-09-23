---
type: module
path: "@root/website/src/Web/LiveReload.pudu"
fidelity: Active
tags: [website, web, development]
aliases: [website Web LiveReload]
---
# Website Web LiveReload

Keeps every open page showing the site as it is on disk while `website/scripts/dev.sh` runs it under
`pudu run --watch`. The watch starts the site again when a source, a documentation page, data, a
stylesheet, a script, or a playground example changes, and tells it `PUDU_WATCH` (which start this
is) and `PUDU_WATCH_CHANGED` (what changed before it).

`fromEnvironment` reads those; a site run any other way is not watched and none of this applies, so
the prerendered pages and the function never carry it. [[website Main]] adds `middleware` to the
server when watched. It answers `/__pudu/reload` with the start and the changed files, serves the
script under `/__pudu/live/` from `website/dev/live-reload` — outside `website/public`, which a
deployment copies — places the script last in every page's body, and sends every answer with
`cache-control: no-store`. The server sets `Content-Length` when it writes, so the grown body is
framed correctly.

The page asks every quarter second while visible. When the start moves by one and only stylesheets
changed, it swaps each stylesheet once the new one has loaded, keeping the scroll position and
anything typed; otherwise it reloads. While the site starts again it does not answer, and the page
keeps asking.

Resolved Grill Log: watch the files in the compiler, not the site. _Rationale:_ the watch already
reads modification times; `Std.Fs` gives no modification time, so a site-side watcher would have to
read and hash every input, the catalogue among them, on every look. _Rejected:_ a configuration
file listing what to watch; the site finds out it is watched from the environment the watch gives
it.
