---
type: script
path: "@root/website/scripts/build-vercel.sh"
fidelity: Active
tags: [website, vercel, build]
aliases: [Vercel output builder]
---
# Vercel Output Builder

Produces a Build Output API v3 directory (`.vercel/output`) from the public catalogue, a Pudu Lambda
function, static CSS, Nunito fonts, logos, and canonical HTML pages rendered directly by Pudu. The
function contains the Lambda-targeted musl runtime and its loader; no JavaScript adapter is included.

Resolved Grill Log: dynamic search reaches the same Pudu router and ranking service as local requests
and tests, while canonical pages resolve directly from Vercel's static edge output. The builder refuses
to package a function unless both the Lambda runtime and its matching musl loader are present.
