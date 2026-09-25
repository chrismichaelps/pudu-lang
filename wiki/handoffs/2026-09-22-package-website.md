---
type: handoff
status: ACTIVE
date: 2026-09-22
issue: 297
tags: [handoff, packages, website, registry]
aliases: [2026-09-22-package-website]
---

# Package Website Handoff

## Objective

Finish issue #297: build the public package catalog, handle and project pages, source and API views,
releases, and install control from the registry snapshot under [[architecture/PACKAGES]].

## Ownership and role transitions

1. **Language Architect:** the package and website architecture pages govern this slice; no Pudu
   syntax or public standard-library contract changes.
2. **Tooling/Release Engineer:** owns `registry/src/Store/Files.pudu`, `registry/src/Web/Api.pudu`,
   `registry/src/Test/Registry.pudu`, `test/package-registry.py`, and the website snapshot/build
   scripts. The registry's file-list endpoint reports unreadable release trees.
3. **Website Engineer:** owns `website/src/`, package assets, style, and fixtures. The local router,
   static prerender, and dynamic package search consume one public snapshot.
4. **Independent reviewer:** checked the diff without editing. Binary and encoded paths, invalid
   documentation, absent release trees, canonical file URLs, install age guidance, and bounded
   snapshot downloads were raised and corrected.
5. **Website Engineer:** after local browser inspection of the `@alice` fixture, revised the catalog
   and project header as original Pudu designs, simplified the package list, and corrected the
   mobile search button and install panel placement.
6. **Website Engineer:** replaced the Source tab with a code view (file sidebar and filter, breadcrumb, file card, server-side Pudu highlighting, rendered Markdown, declarations outline) and added GitHub Issues, Pull requests, and Stars links with counts; checked in the browser at desktop and phone widths.
7. **Forensic Guardian:** reconciles source, module mirrors, MOCs, architecture, changelog, and
   this handoff before recording the commit.
8. **Website Engineer:** carries the shared banner onto reading, reference, search, policy, and
   fallback pages; replaces catalogue cards with linked rows and adds most-starred discovery on
   larger snapshots. The source mirrors and stylesheet record the shared visual contract.
9. **Forensic Guardian:** checks wiki parity and the final website diff before the direct `dev` commit.
10. **Language Architect:** extends [[architecture/PACKAGES]] with a native read-only ticket and
    contribution surface sourced from GitHub at build time, and a combined project/declaration
    search result view.
11. **Website Engineer:** owns the GitHub snapshot, package model, search, project frame,
    discussion views, routes, sitemap, stylesheet, fixtures, and focused tests for that extension.
12. **Independent reviewer and Forensic Guardian:** review the extension and its source/wiki parity
    before the direct `dev` commit.
13. **Independent reviewer:** found and verified fixes for contribution URLs, initial Markdown
    headings, the JSON-only serverless package loader, and static discussion routes.
14. **Website Engineer:** owns bounded pagination for catalogue, handle, search, ticket, and
    contribution lists, the browser scroll enhancement, static page rewrites, and mapped local
    source-tree icons. A 25-project/25-ticket browser fixture verified rows append on scroll.
15. **Website Engineer:** added shared empty banners, live loading status, and loaded-list state;
    the 404 banner now describes any missing route. The browser showed empty search, the 404,
    and loading during a delayed second-page request, then 25 loaded rows.
16. **Forensic Guardian:** found a keyboard-focus loss when a focused next-page link was hidden.
    The link now stays visible while focused and hands focus to the first new row when the final
    page removes it. The reviewer found no remaining actionable issue in the requested UI slice.
17. **Website Engineer:** owner images now use the GitHub profile avatar, with a hosted GitHub URL
    if local copying fails and a geometric user silhouette if neither is usable. The fallback was
    inspected at phone width in the browser; a deliberately missing local image was removed by the
    browser enhancement, leaving the silhouette. The fake GitHub gate verifies that the build copies
    an avatar, and the fixture test holds local, remote, and empty cases.
18. **Forensic Guardian:** reviewed the avatar fallback, later-page image binding, cache revision,
    tests, and wiki parity; no actionable finding remains.
19. **Website Engineer:** owns the live search enhancement, declaration filter, responsive package
    list, stylesheet, route wiring, tests, and corresponding vault mirrors.
20. **Forensic Guardian:** reviews the source/wiki parity and focused browser evidence before the
    direct `dev` commit.
21. **Language Architect (#300):** a package filter means "search inside this project"; queries take
    four forms (owner, owner/project, name, signature shape); one ranking service feeds the full
    results page and the new `GET /packages/suggest` JSON. Recorded in [[architecture/PACKAGES]] and
    [[website Service PackageSearch]].
22. **Website Engineer (#300):** owns `website/src/Service/PackageSearch.pudu`,
    `website/src/View/Packages/Suggest.pudu`, `Catalog.pudu`, `Frame.pudu`, the suggest routes,
    `website/public/assets/packages/search.js` and `search/`, `site.css`, `Test/PackageSearch.pudu`,
    the website suite's search checks, the Vercel route, and their mirrors. Replaces the gradient
    visual system with ink on the logo's soft blue across every page.
23. **Independent reviewer (#300):** reviewed the diff without editing and found six issues:
    title-case queries lost project and owner results; the auto-selected first row let Enter, Right
    Arrow, and Tab act on unchosen or stale rows; listbox headings were not groups; a footer column,
    a dead selector, and an unused class; and duplicate shape identifiers. All were fixed and tested.
24. **Website Engineer (#300):** at the owner's direction, surfaces use the soft blue of the logo's
    `P`, and the dark gradient banner heads every page, including search results, owner profiles,
    and project pages. The project tabs (Overview, Docs, Releases, Tickets, Contributions) are
    redrawn as file, ledger, and post layouts under one tab heading.

## Delivery exception

The repository owner directs issue work to commit directly to `dev`, reference the delivered commit
on the issue, and close the issue only when the hosted registry and website flow are verified. No PR
is created.

## Evidence

- `registry/src/Test/Registry.pudu`: 40 assertions pass, including an unreadable release tree.
- `website/src/Test/Website.pudu`: 194 assertions pass against the `@alice/json-kit` snapshot,
  including empty, loaded, loader, and 404 markup, both suggest routes, and the project search box.
- `website/src/Test/PackageSearch.pudu`: 27 assertions pass (ranking, query forms, filters, bounds,
  JSON reply); a deliberately wrong expectation was seen to fail.
- #300 browser check on a nine-project fixture at the pane's desktop width and at 375px: catalogue
  ledger and side column, owner/project/name/shape suggestions, Right Arrow filter chip and
  Backspace removal, Enter opening the selection, the project page's fixed box, results page, install
  panel on a phone, and no horizontal overflow; no console errors.
- The latest package UI and native discussion suite holds 189 assertions. The GitHub stand-in
  integration passes with separate discussion documents and singular pull request detail URLs.
- `test/package-registry.py`: local fake GitHub and registry flow passes, including snapshot and
  generated API catalogue.
- Static prerender with the fixture writes 3,703 canonical pages, including binary and encoded
  source filenames and numbered list pages. The optimized `cabal test all --enable-optimization=2 --ghc-options=-Werror`
  gate passes. The local website at port 8123 was inspected in a browser across catalog, overview,
  install, source, docs, and releases.

## Exact next action

Publish a real package repository with the `pudu-package` topic (for example with `pudu release`), set
`GITHUB_TOKEN` in the website build, deploy, and verify its pages before closing #297 and #299.

## Referenced by

[[handoffs/_MOC]] · [[architecture/PACKAGES]] · [[website Service Packages]]
