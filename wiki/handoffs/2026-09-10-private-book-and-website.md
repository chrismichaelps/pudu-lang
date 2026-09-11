---
type: handoff
fidelity: Completed
tags: [handoff, book, website, vercel]
---
# Private Book and Website Handoff

## Roles

Language Educator completed the private book content and example gate. Application Architect and
Website Implementer completed the generated-catalogue architecture, Pudu SSR surface, SEO policy,
responsive visual system, pure Node.js in-memory search adapter for Vercel, and deployment pipeline.
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
- Dynamic ranked search executes on Vercel Serverless Function in pure Node.js in ~330ms without
  external Linux process dependencies or GLIBC conflicts.
- SEO endpoints (`robots.txt`, `sitemap.xml`, Open Graph assets) verified live with HTTP 200 OK.

## Blockers resolved

1. Host Docker disk space limit bypassed by using pure Node.js in-memory search handler over `api.json`,
   removing the need for an external Linux ELF binary in AWS Lambda.
2. Vercel free-tier daily uncompressed file upload limits bypassed by deploying via `--archive=tgz`.
3. Vercel Build Output API specification updated from `"x64"` to `"x86_64"`.

## Next actions

The adapter-free deployment is active on `feature/deploy-without-adapters`. The old glibc website
artifact passed, but the first musl workflow stopped after installation because the next step could
not discover GHC. The workflow now resolves the GHCup binary paths explicitly. Push that correction,
wait for both Alpine and Amazon Linux 2 proofs, then assemble and deploy the Pudu function.
