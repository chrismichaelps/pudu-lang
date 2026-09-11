---
type: module
path: "@root/website/src/Prerender.pudu"
fidelity: Active
tags: [website, pudu, prerender, seo]
aliases: [website Prerender]
---
# Website Prerender

Calls `Web.render` for every canonical path returned by `Seo.paths`, then writes each successful
response into the Vercel static output tree. It also writes `robots.txt` and `sitemap.xml` without
starting a server or making loopback requests.

Resolved Grill Log: the sitemap path source and prerender path source are identical, and any route
that fails to answer with HTTP 200 makes the build fail instead of publishing an error page.
