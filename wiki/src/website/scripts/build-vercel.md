---
type: script
path: "@root/website/scripts/build-vercel.sh"
fidelity: Active
tags: [website, vercel, build]
aliases: [Vercel output builder]
---
# Vercel Output Builder

Produces a Build Output API v3 directory (`.vercel/output`) from the public catalogue, an optional package snapshot, a Pudu Lambda
function, static CSS, Nunito fonts, logos, and canonical HTML pages rendered directly by Pudu. The
function contains the Lambda-targeted musl runtime and its loader; no JavaScript adapter is included.
The matching musl `libffi`, `zlib`, `ncursesw`, and `gmp` libraries are copied beside the
function and named directly by its ELF dependencies.
The build asks Pudu to derive a compact search index from `website/data/api.json` and packages that
index for the function. The complete JSON catalogue remains the source for static generation and is
not parsed during a serverless cold start. The prerender is given `PUDU_DOCS_PATH` beside
`PUDU_CATALOG_PATH`, both absolute, so the Markdown documentation pages are found wherever the script
is run from and become static pages; the function never reads them.
Unless `PUDU_PACKAGES_FROM_GITHUB=0`, the builder snapshots the packages GitHub lists (with `GITHUB_TOKEN` for its rate limit), prerenders their pages, copies avatars into static output, and sends only `packages.json` to the function for package search and suggestions; `/packages/search` and `/packages/suggest` route to the function before the static filesystem. A failed snapshot fails the build. Nested project, source, ticket, and contribution paths rewrite to their static files.
Numbered package, handle, ticket, and contribution list paths also rewrite to prerendered files.

Resolved Grill Log: dynamic search reaches the same Pudu ranking and result view as local requests
and tests through a bounded dynamic router, while canonical pages resolve directly from Vercel's static edge output. The builder refuses
to package a function unless both the Lambda runtime and its matching musl loader are present.
It also refuses any missing shared dependency named by the runtime package contract.
The emitted function uses Vercel's current custom-runtime target, `provided.al2023`.
The function is named `dynamic.func`, avoiding the root-path shadowing caused by `index.func`.
Its function configuration carries the build's validated canonical `PUDU_SITE_URL`, so dynamic
no-index pages and social metadata never fall back to a local-development origin.
