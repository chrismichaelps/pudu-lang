---
type: module
path: "@root/website/src/App/Logging.pudu"
fidelity: Active
tags: [website, application, logging]
aliases: [website App Logging]
---
# Website App Logging

Builds the site's `pudu-lang-log` logger from [[website Config]]'s logging settings. Every event goes to
standard error, so standard output stays free for what a program answers ([[website Platform Render]]
writes its response envelope there). `text` writes the console template, coloured only on a terminal;
`json` writes compact newline-delimited JSON with the rendered message, which the platform's log
search reads. Events carry `Application` = `pudu-lang.org` and the `SourceContext` of what wrote them.
`quiet()` is a logger that writes nothing, for suites and for renders whose logs nobody reads.

Resolved Grill Log: one logger is built at startup and handed down; nothing reads the environment per
event. _Rejected:_ writing to standard output (corrupts the renderer's protocol).
