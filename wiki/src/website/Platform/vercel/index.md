---
type: adapter
path: "@root/website/platform/vercel/index.js"
fidelity: Active
tags: [website, vercel, adapter]
aliases: [Vercel process adapter]
---
# Vercel Process Adapter

Keeps one bundled Pudu HTTP server per warm Vercel function instance and proxies dynamic requests
to it. It derives a trusted canonical origin from Vercel's deployment environment and restarts the
child after a failed startup or proxy attempt.

Resolved Grill Log: JavaScript owns no routes, search rules, HTML, or SEO policy; it is only the
process and HTTP boundary required by Vercel's supported function runtimes.
