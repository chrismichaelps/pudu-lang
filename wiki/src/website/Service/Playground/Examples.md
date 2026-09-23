---
type: module
path: "@root/website/src/Service/Playground/Examples.pudu"
fidelity: Active
tags: [website, playground, service]
aliases: [website Service Playground Examples]
---
# Website Playground Examples

Loads `NN-slug.pudu` examples once at start; the first two comment lines are the title and summary. Reserved slugs (`shared`, `open`) are refused.

The menu holds one program for each documentation chapter a confined run can execute — functions,
shapes, numbers, text, collections, control flow, errors, ownership, traits, generics, compile time
and macros, testing, JSON and CSV, HTML, HTTP routes, concurrency, time and randomness. Chapters
whose work a confined run refuses (files, foreign calls, a listening socket) are shown through what
it can run: the HTTP example dispatches requests to its router without opening a port.
`test/docs-examples.py` runs each one with `pudu run --confined`, exactly as the sandbox does.

Resolved Grill Log: a directory with no examples stops the site from starting.
