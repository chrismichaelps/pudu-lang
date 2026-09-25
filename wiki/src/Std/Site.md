---
type: module
path: "@root/lib/Std/Site.pudu"
fidelity: Active
domain: "[[Pudu Program]]"
subsystem: "[[Standard Library]]"
grammar: "[[grammar/pudu]]"
tags: [module, stdlib, web, deployment, performance]
aliases: [Std Site]
---

# Std Site

## Purpose and interface

The build step a Pudu web application calls to become files a host serves
([[ADR-0024-building-a-web-application-for-any-host]]).

- `type Target = Static | Vercel | Netlify | CloudflarePages`; `targetFromEnvironment()` reads
  `VERCEL`, `NETLIFY`, `CF_PAGES`; `defaultOutput(target)`.
- `type Options = { output, publicDirectory, workers, target, fallback: Option[Str] }`; `options()`
  gives the detected host, its output, `public`, eight workers, no fallback.
- `type Refusal = { path, reason }`; `type Report = { rendered, written, unchanged, copied, refused }`;
  `succeeded(report)`, `summary(report)`.
- `type SiteError = BadOptions(Str) | Unwritable(Str, Str) | UnreadablePublic(Str, Str)`; `explain`.
- `fileFor(path, contentType) -> Result[Str, Str]`, `pagesDirectory(options)`,
  `vercelConfig(fallback, hasNotFound) -> Str`.
- `build(options, paths, render) -> Result[Report, SiteError]`.

## Semantics

- `render` runs on `workers` threads through [[Std Concurrent]] `mapBounded`; outcomes keep input
  order, so the report lists refusals in the order paths were given.
- A path must start with `/` and contain no empty, `.`, or `..` segment, no backslash, `?`, `#`, or
  control character; it is refused otherwise and nothing is written for it.
- A non-`200` response is refused (`answered <code>`) and not written.
- File placement is decided by the response's `content-type`: an HTML response is
  `<path>/index.html` (`/` is `index.html`, `/404` is `404.html`); any other content type is written
  at exactly its path; with no content type, a last segment ending in a known file extension is a file.
- A file is rewritten only when its bytes differ; the public directory is copied the same way.
- `Vercel` writes pages under `<output>/static` and `<output>/config.json` with routes: filesystem,
  then `^/(.+?)/?$` → `/$1/index.html` when that file exists, then the `fallback` function or the
  site's `404.html`. Other targets need no configuration and write none.
- The build fails only when options are unusable, the output cannot be created, or a public file
  cannot be read or written.

## Grill Log

- **Q:** Decide file versus page by the path's extension? **A:** By the response's content type.
  _Rationale:_ page names such as `Std.Json` and `Std.Html` carry extension-shaped dots; the response
  knows what it is. _Rejected:_ an extension list alone (kept only as the no-content-type fallback).
- **Q:** Clean an unsafe path? **A:** Refuse it. _Rationale:_ a cleaned path writes a page somewhere
  other than where it was asked for.
- **Q:** Write every file on every build? **A:** Only changed ones. _Rationale:_ an unchanged tree
  then deploys nothing, and timestamps keep meaning something.
- **Q:** Delete files no longer rendered? **A:** Not in this slice. _Rationale:_ the output may hold
  files the application placed there; pruning needs a manifest of what the build owns.

## Dependencies and consumers

- Depends on [[Std Concurrent]], [[Std Env]], [[Std Http]], [[Std Io]].
- Consumed by [[website Prerender]]; reached by [[Uses Site All]].

## Referenced by

[[src/Std/_MOC]] · [[architecture/STDLIB]] · [[ADR-0024-building-a-web-application-for-any-host]]

## Routes before pages (#357)

- `type Route = ToFunction{pattern, methods} | Header{pattern, name, value} |
  Redirect{pattern, location, permanent}`, carried by `Options.routes` (default empty).
- One pattern language for every host: a path starting `/`, with at most a trailing `*` matching the
  rest. `patternRegex` gives the anchored regular expression Build Output matches (every other
  character literal).
- `vercelConfig(fallback, hasNotFound, routes)` emits redirects (308/307 with `Location`), headers
  (`continue: true`), function routes (with `methods` when listed; left out without a fallback),
  then `filesystem`, `/` → `index.html`, pages by directory, and the fallback or `404.html`.
- `headersFile(routes)` and `redirectsFile(routes)` give the `_headers` and `_redirects` files that
  Netlify and Cloudflare Pages read; they are written into the pages directory when not empty.
- Validation refuses a pattern that does not start with `/`, holds a space, or has `*` anywhere but
  the end; a header name that is empty or holds `:`, a space, or a line break, or a value with a
  line break; a method that is not upper case; and an empty or spaced redirect location.

Resolved Grill Log: one pattern language rather than each host's own, so an application's routes
are written once; function routes apply only where a function runs, and are omitted rather than
pointed at nothing elsewhere.
