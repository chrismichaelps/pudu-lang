# Deploying

A Pudu web application has two halves. Pages that look the same for every visitor are files, served by a CDN in one round trip. Everything else is answered by the application's handler, running as a server or as a serverless function. This chapter covers both, from one program.

## Pages as files

`Std.Site` turns the pages an application names into the files a host serves. The application passes the paths and the same `render` function its server uses, so there is one renderer and nothing to keep in step:

```pudu
module BuildSite

import Std.Env as Env
import Std.Http as Http
import Std.Site as Site

fn render(path: Str) -> Http.Response {
  let body = if path == "/" { "<h1>Home</h1>" } else { "<h1>{path}</h1>" }
  Http.Response{status: Http.status(200), headers: [("content-type", "text/html; charset=utf-8")], body: body, binaryBody: None}
}

fn main() -> Int {
  let settings = Site.Options{..Site.options(), output: Env.temporaryDirectory() + "/pudu-docs-site", publicDirectory: "", target: Site.Static}
  match Site.build(&settings, &["/", "/about", "/robots.txt"], render) {
    case Ok(report) => { if Site.succeeded(&report) { 0 } else { 1 } }
    case Err(_) => 1
  }
}
```

`/` becomes `index.html` and `/about` becomes `about/index.html`, which every static host serves for `/about`. A response that is not HTML, such as `/robots.txt`, is written at exactly its path. Pages render on several threads at once, and a file whose bytes have not changed is left alone, so rebuilding an unchanged site writes nothing and a deployment uploads only what changed. A page that does not answer `200`, or a path that could leave the output directory, is reported and not written.

`Site.options()` reads which host the build is running on: `Vercel`, `Netlify`, `CloudflarePages`, or `Static` when none of them is present. Each host gets the layout it reads, and for Vercel the routing too, derived from the files that were written rather than listed by hand. Name a function in `fallback` and every request no page answers goes to it.

## Routes, declared once

Some requests are not for files. An API, a form post, or a search goes to the function; an old address
redirects; a directory of fingerprinted assets gets a long cache policy. These are rules, and each
host spells them differently. `Options.routes` states them once, and the build writes each host's
form: entries in Vercel's Build Output configuration, or `_headers` and `_redirects` for Netlify and
Cloudflare Pages.

```pudu
module SiteRoutes

import Std.Site as Site

fn main() -> Int {
  let rules = [
    Site.Redirect{pattern: "/guide", location: "/docs", permanent: true},
    Site.Header{pattern: "/assets/*", name: "cache-control", value: "public, max-age=31536000, immutable"},
    Site.ToFunction{pattern: "/api/*", methods: []},
    Site.ToFunction{pattern: "/contact", methods: ["POST"]}
  ]
  let _ = print(Site.redirectsFile(&rules))
  let _ = print(Site.headersFile(&rules))
  if Site.vercelConfig(Some("dynamic"), true, &rules).contains("\"status\": 308") { 0 } else { 1 }
}
```

A pattern is a path, optionally ending in `*` to match everything beneath it. Redirects are answered
first, then headers are added, then requests for the function go to it before any file is looked for.
A request that names no file and no rule reaches the fallback function. A pattern, header, or method
a host could not accept is refused when the build starts, with a sentence saying which one, rather
than failing silently after deployment.

## The handler as a function or a server

The rest of the application is its handler, and `pudu build` writes it as one file. For a machine other than the one building, name the host:

| Command | Writes |
| --- | --- |
| `pudu build src/Main.pudu` | one executable for this machine |
| `pudu build src/Main.pudu --target linux-musl-x86_64` | one executable for any x86_64 Linux |
| `pudu build src/Function.pudu --target lambda-x86_64 -o dynamic.func` | a function directory: `bootstrap`, its loader, and its libraries |

A target fetches the runtime published with your compiler's release, once, and keeps it. Every file is checked against the release's SHA-256 manifest, and the runtime must have been built from the same sources as your compiler, so the program starts from what was checked when it was built instead of checking every module again on each cold start. A compiler built from a checkout has no published runtime; attach it to one you built with `--runtime`.

A function is written with `Std.Http.Server.Lambda`, which asks the platform for requests over the Lambda runtime interface. The same routes serve the local server, the function, and the prerender, so a page cannot look one way in development and another in production.
