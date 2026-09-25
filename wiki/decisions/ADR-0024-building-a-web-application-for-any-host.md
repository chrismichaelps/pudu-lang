---
type: decision
status: ACCEPTED
date: 2026-09-25
tags: [decision, web, deployment, performance, stdlib]
aliases: [ADR-0024-building-a-web-application-for-any-host, ADR-0024 Building a Web Application for Any Host]
---

# ADR-0024: Building a Web Application for Any Host

## Context

A Pudu web application is served by one handler (`Std.Http.Server`, `Std.Http.Server.Lambda`), and
the pages that do not depend on a request are best served as files from a CDN. Until now nothing
turned the first into the second. The project website did it with a bespoke prerender loop and a
shell script that wrote host routing by hand; another developer had nothing to reuse, and each host
lays files out and routes them its own way.

Measured on the project website: 3,705 pages rendered one at a time take 91 s; the host routing is
180 lines of shell with every page family written out; producing the serverless function needs a
musl runtime whose toolchain is built locally in a container over hours. A bundle attached to that
runtime then re-checked every module on every cold start (fixed by #352).

## Decision

**One build step, called by the application, with an adapter per host.** `Std.Site.build(options,
paths, render)` is ordinary Pudu: the application names the paths it serves statically and the
function that renders one — the same `render` its server and its function use — and the build
writes every page where the chosen host looks for it, together with that host's routing, derived
from what was written rather than listed by hand.

- **Targets** are `Static`, `Vercel`, `Netlify`, and `CloudflarePages`. `targetFromEnvironment`
  reads the variables each host's build sets, so the same program builds correctly wherever it runs.
  A target that needs no configuration writes none.
- **Layout is fixed and portable.** `/` is `index.html`, `/docs` is `docs/index.html`, a path whose
  last segment has an extension is that file, and `/404` is `404.html`, the name every static host
  serves for a miss.
- **Speed comes from the shape of the work, not from a second implementation.** Pages render on a
  bounded pool of threads; a page whose bytes are already on disk is not rewritten, so a rebuild
  touches only what changed and a CDN upload sends only what changed. Later slices add: the
  effects each page performs traced by the runtime, so a page whose inputs did not change is not
  rendered at all; runtimes published per release and verified, so no local toolchain build; and
  artefacts that start from checked products (#352).
- **Safety is part of the layout.** A path that could leave the output directory, or that names a
  query, fragment, or control character, is refused before anything is written; a page that does
  not answer `200` is reported and not written, because a written error page is a working-looking
  page with the wrong content.

## Consequences

- A developer deploys a Pudu site with one program and one command, on any of the four hosts,
  without writing host configuration.
- The website keeps one renderer: its prerender becomes a call to `Std.Site.build`.
- Dynamic routes still need the function adapter and a runtime for the host; that packaging is the
  next slice and is named rather than implied.

## Rejected

- **A command-line build that discovers pages itself.** Which pages exist is the application's
  knowledge (its sitemap), and a build that guessed would render pages the application never
  meant to publish.
- **A second renderer in the host's own language.** Two renderers disagree, and the deployed one
  is then the untested one.
- **Rendering by starting the server and fetching every page.** It measures sockets rather than
  rendering, and needs a port, a readiness wait, and a shutdown the build does not otherwise need.

## Referenced by

[[decisions/_MOC]] · [[architecture/WEB]] · [[architecture/DEPLOYMENT-TARGETS]] · [[Std Site]]
