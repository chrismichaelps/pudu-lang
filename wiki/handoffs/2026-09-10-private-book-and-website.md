---
type: handoff
fidelity: Active
tags: [handoff, book, website, vercel]
---
# Private Book and Website Handoff

## Roles

Language Educator completed the private book content and example gate. Application Architect and
Website Implementer completed the generated-catalogue architecture, Pudu SSR surface, SEO policy,
responsive visual system, Pudu-native Lambda entry, and deployment pipeline.
Application Architect transitioned to Standard Library Boundary Implementer for the framed-response
completion defect exposed by the live Lambda Runtime API. Owned files are `Std/Http/Client.pudu`,
`Std/Http/Message.pudu`, `UsesHttpClient.pudu`, the protocol count assertion, and their vault mirrors.
Forensic Guardian validation is represented by the focused route suite, browser and TTFB latency checks,
example audit, full repository test suite, and live production verification. Feature branch
`feature/228-pudu-website` was merged into `dev` via PR #228.

## Current state

- The ignored private book is versioned as `0.1.0-edition.2`; 76 extracted complete programs pass,
  and print, digital, cover, and EPUB outputs passed their format gates.
- The Pudu website reads 3,245 generated public declarations, renders all canonical pages, and
  exposes dynamic ranked search. The short logo is the favicon; global navigation includes Guide,
  API, About, Donate, and the GitHub repository. The About page describes Pudu 0.1, Haskell's role,
  and the author's LinkedIn and GitHub profiles. The footer carries the copyright notice.
- Same-name function variants share a kind-qualified symbol page; type and function names remain
  distinct on case-insensitive filesystems. The final local capture produced 3,375 routes and files.
- `pudu check`, `pudu fmt --check`, 36 website route assertions, 25 repository example checks, and
  the isolated full `cabal test all` run pass. Desktop and 390px browser checks pass without
  horizontal overflow.
- The existing production deployment remains at `https://website-ivory-one-hyy8j9ljag.vercel.app/`
  while the adapter-free replacement is verified on preview.
- The replacement output contains all 3,375 Pudu-prerendered routes for direct Vercel Edge CDN
  delivery and a Pudu `provided.al2023` function for ranked search and dynamic failures.
- Dynamic ranked search uses the same `Service.Search` implementation locally, in the website
  fixture, and in the replacement function; live preview verification remains before promotion.
- SEO endpoints (`robots.txt`, `sitemap.xml`, Open Graph assets) verified live with HTTP 200 OK.

## Blockers resolved

1. The duplicate Node search adapter and `website/platform/vercel` folder were removed. The Pudu
   runtime is built against musl; its Lambda copy names a packaged loader under `/var/task`.
2. Vercel free-tier daily uncompressed file upload limits bypassed by deploying via `--archive=tgz`.
3. Vercel Build Output API specification updated from `"x64"` to `"x86_64"`.

## Next actions

The adapter-free deployment is active on `feature/deploy-without-adapters`. Its Lambda executable
names the packaged loader and four musl libraries under `/var/task`; CI executes that layout on
Alpine and Amazon Linux 2023 with Vercel-like host library paths. The function is `dynamic.func`,
its catalogue remains at `website/data/api.json`, and the output targets `provided.al2023`.

The first previews exposed and resolved host-library substitution, static-root shadowing, catalogue
layout, and HTTP framing defects. The framing-aware client and its persistent-loopback regression now
pass `cabal test all`; the next exact action is to build the musl runtime from this commit and redeploy
the generated Pudu function.
