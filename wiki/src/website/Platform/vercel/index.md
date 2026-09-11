---
type: adapter
path: "@root/website/platform/vercel/index.js"
fidelity: Active
tags: [website, vercel, adapter]
aliases: [Vercel search adapter]
---
# Vercel Search Adapter

Implements an in-memory catalogue search handler and HTML renderer on Vercel Serverless Functions.
It loads `api.json` into memory on cold start (< 5ms) and evaluates search queries using the Pudu
ranking algorithm (exact name, qualified name, prefix, substring, signature, and documentation matches).

Resolved Grill Log: JavaScript owns only the runtime search endpoint and HTML result template for
dynamic queries. Static pages are pre-rendered into `.vercel/output/static/` by Pudu ahead of time.
Eliminates ELF Linux child-process dependencies and host `glibc` version mismatch on AWS Lambda / Vercel.
