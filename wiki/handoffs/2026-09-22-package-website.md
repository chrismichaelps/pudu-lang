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

## Delivery exception

The repository owner directs issue work to commit directly to `dev`, reference the delivered commit
on the issue, and close the issue only when the hosted registry and website flow are verified. No PR
is created.

## Evidence

- `registry/src/Test/Registry.pudu`: 40 assertions pass, including an unreadable release tree.
- `website/src/Test/Website.pudu`: 163 assertions pass against the `@alice/json-kit` snapshot.
- `test/package-registry.py`: local fake GitHub and registry flow passes, including snapshot and
  generated API catalogue.
- Static prerender with the fixture writes 3,714 canonical pages, including binary and encoded
  source filenames. The optimized `cabal test all --enable-optimization=2 --ghc-options=-Werror`
  gate passes. The local website at port 8123 was inspected in a browser across catalog, overview,
  install, source, docs, and releases.

## Exact next action

Connect a hosted registry containing the public `@alice/json-kit` test project to the website build
through `PUDU_PACKAGES_REGISTRY`, then verify its deployed pages before closing #297.

## Referenced by

[[handoffs/_MOC]] · [[architecture/PACKAGES]] · [[website Service Packages]]
