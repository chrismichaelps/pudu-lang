---
type: handoff
status: IN_REVIEW
issue: 656
aliases: [Hackage Transport Delivery]
tags: [handoff, delivery]
---
# Hackage Transport Delivery

Fresh feature/656-hackage-https starts from fetched development c13dd93e. The pending engine
foundation and LSP root repair remain in reviewed PRs #653 and #655; neither is reverted.

Role transitions: Architect → Release Engineer → Test Engineer → independent Forensic Guardian.
Release Engineer owns website-linux.yml; Test Engineer owns hackage-transport.py; Architect owns
complete mirrors/navigation. Resolved mirrors precede implementation. Preserve unrelated work.

Observed failure: PR #653 renderer job failed at its explicit second cabal update, with HTTP 403
from Hackage mirror timestamp metadata, before compilation. Canonical Cabal configuration CLI
can replace the repository URL with HTTPS while retaining signature checks and unrelated options.
Experiment: repository augmentation replaces the repository inventory rather than merging by
name. The resolved CI-only contract therefore deliberately selects Hackage alone, retaining cache
paths and scalar settings. It is not a contributor configuration migration tool.

Evidence: focused real-Cabal checks pass for HTTP-to-HTTPS configuration, signed metadata,
scalar/cache preservation, sole Hackage inventory, idempotence, missing and malformed files.
Independent reviewer reran the test and confirmed malformed config and invalid destinations
remain fatal. Public HTTPS timestamp retrieval succeeds with signed metadata; this does not
establish the hosted runner's network behavior. No index download or full gates were run locally.
Implementation and Forensic Guardian reviews pass without findings.

Exact next action: observe the repair PR's configured CI fetch while implementing Ark dependency
enforcement, then integrate reviewed foundations once their required checks are green.

## Referenced by

[[handoffs/_MOC]] · [[Website Linux Workflow]] · [[Hackage Transport Test]]
