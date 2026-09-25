---
type: module
path: "@root/website/src/Prerender.pudu"
fidelity: Active
tags: [website, pudu, prerender, seo]
aliases: [website Prerender]
---
# Website Prerender

Loads the catalogue, documentation pages, and public package snapshot; calls `Web.render` for every canonical path returned
by `Seo.paths` — documentation pages included — then writes each successful response into the Vercel
static output tree. A documentation directory that cannot be read fails the build. It also writes `robots.txt` and `sitemap.xml` without
starting a server or making loopback requests.

Resolved Grill Log: the sitemap path source and prerender path source are identical, and any route
that fails to answer with HTTP 200 makes the build fail instead of publishing an error page.

## Built through Std.Site (#351)

The pages are written by [[Std Site]] `build` rather than a loop of its own: eight at a time, with
the file for each path decided by its response (an HTML response is a directory's `index.html`, so
`/module/Std.Json` is a page; `robots.txt` and `sitemap.xml` are written at their paths), and a file
whose bytes are already current left alone. Measured on 4 cores: 91 s before, 26 s after, with the
3,705 files byte-identical; a rebuild with nothing changed writes none. Refused paths are reported
one per line and fail the build.

## Writes the Build Output routing (#357)

The prerender is given the Build Output directory and builds with the `Vercel` target: pages under
`static/`, and `config.json` from [[Std Site]] — the `/guide` redirect, cache policies for asset
families, the playground, API, package-search, shared-program, and search routes sent to the
`dynamic` function, then files, `/`, pages by directory, and the function for the rest.
