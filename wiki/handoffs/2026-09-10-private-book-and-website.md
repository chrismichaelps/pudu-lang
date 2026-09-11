---
type: handoff
fidelity: Completed
tags: [handoff, book, website, vercel]
---
# Private Book and Website Handoff

## Roles

Language Educator completed the private book content and example gate. Application Architect and
Website Implementer completed the generated-catalogue architecture, Pudu SSR surface, SEO policy,
responsive visual system, Pudu-native Lambda entry, and deployment pipeline.
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
- Vercel is deployed to Production at `https://website-ivory-one-hyy8j9ljag.vercel.app/`.
- All 3,375 static pre-rendered routes serve with sub-350ms TTFB directly from Vercel Edge CDN.
- Dynamic ranked search is served by the Pudu Lambda function through the same `Service.Search`
  implementation used locally and in the website fixture.
- SEO endpoints (`robots.txt`, `sitemap.xml`, Open Graph assets) verified live with HTTP 200 OK.

## Blockers resolved

1. The duplicate Node search adapter and `website/platform/vercel` folder were removed. The Pudu
   runtime is built against musl; its Lambda copy names a packaged loader under `/var/task`.
2. Vercel free-tier daily uncompressed file upload limits bypassed by deploying via `--archive=tgz`.
3. Vercel Build Output API specification updated from `"x64"` to `"x86_64"`.

## Next actions

The adapter-free deployment is active on `feature/deploy-without-adapters`. Amazon Linux now reaches
the packaged loader and reports the four remaining dynamic musl libraries. The Lambda runtime uses
an `$ORIGIN` search path and the workflow packages those exact dependencies. Vercel rejected the old
`provided.al2` metadata before deployment; the output and proof now target `provided.al2023`. Rerun
that proof. The first accepted preview showed Vercel's host library path selecting incompatible
glibc libraries and `index.func` shadowing static `/`; bind dependencies to `/var/task`, package
transitive `libtinfo`, use `dynamic.func`, then redeploy and test the Pudu function.
