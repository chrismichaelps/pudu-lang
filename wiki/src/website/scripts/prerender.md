---
type: script
path: "@root/website/scripts/prerender.mjs"
fidelity: Active
tags: [website, ssr, static, vercel]
aliases: [Pudu documentation prerender]
---
# Pudu Documentation Prerender

Starts the bundled Pudu server once, reads only route identities from the generated catalogue, and
captures the home, guide, about, donation, module, symbol, robots, and sitemap responses into Vercel
static output.

Symbol routes are deduplicated before capture. Multiple catalogue entries may intentionally share
one module, kind, and public name; Pudu renders those declarations together at that canonical
route. The kind path segment prevents uppercase types and lowercase functions from overwriting one
another on the macOS build filesystem.

Resolved Grill Log: the script chooses paths and stores responses; Pudu still owns every response
body, status, route decision, metadata tag, and sitemap entry.
