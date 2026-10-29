---
type: handoff
status: IN_REVIEW
issue: 654
aliases: [Library Catalog Delivery]
tags: [handoff, lsp]
---
# Library Catalog Delivery

Fresh feature/654-lsp-library-roots starts from fetched development c13dd93e, independently
of the pending engine foundation PR #653. Existing untracked build artifacts remain untouched.

Role transitions: Language Architect → Tooling Engineer → Test Engineer → independent reviewer
and Forensic Guardian. Tooling Engineer owns ModuleCatalog.hs; Test Engineer owns its new spec,
Main.hs registration and the test manifest. Architect owns matching mirrors and navigation.
Complete resolved mirrors precede implementation. No Pudu syntax or execution meaning changes.

Repair: replace positional root subtraction and a duplicated Std-only allowlist with compiler
root-policy membership. This fixes installed-package completion today and automatically follows
the integrated Ark root when #653 lands. Use focused properties and warning-free affected builds;
the current delivery instruction excludes repeated full gates.

Evidence: the focused regression fails on the old algorithm at Std library admission, then
passes 100 checks with the repair under `-Wall -Werror`. Affected optimized library/executable
builds pass with `-Werror`; existing catalog/import-path properties and test registration build
are checked separately. Independent implementation and forensic reviews pass; no full gates run.

The earlier engine PR #653 has a website CI dependency-fetch failure (Hackage mirror HTTP 403),
before compilation; it remains visible and unmerged. No local engine work is reverted.

Exact next action: publish #654's reviewed PR, then repair the CI package-index transport before
integrating the engine foundation and enforcing its dependency layers.

## Referenced by

[[handoffs/_MOC]] · [[Lsp Module Catalog]] · [[Lsp Module Catalog Spec]]
