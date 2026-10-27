---
type: module
path: "@root/.github/workflows/website-linux.yml"
fidelity: Active
aliases: [Website Linux Workflow]
tags: [module, delivery, website]
---
# Website Linux Workflow

## Purpose and algorithm

On relevant feature pushes or explicit dispatch, build the compiler and Pudu website executable
on Ubuntu and retain the executable as a one-day artifact. Existing toolchain versions, locked
website dependencies, build commands and artifact behavior remain unchanged.

Disable the setup action's automatic Cabal update. Before the one explicit index update, use
`cabal user-config init --augment`, or `update --augment` when initialization refuses an existing
file, to select `https://hackage.haskell.org/` with `secure: True`.
On the disposable runner, select Hackage as the sole repository while preserving scalar build
settings and cache paths; Cabal's repository augmentation replaces the repository inventory.
Let Cabal manage missing files. Configuration/fetch
failure remains fatal. The project index-state pin remains unchanged. [[Hackage Transport Test]]
exercises the actual workflow configuration command without a network fetch.

## Resolved Grill Log

- **Q:** Disable signed metadata to avoid mirror failure? **A:** No; retain verification and
  configure HTTPS before fetching. Do not mask failed updates or use stale-cache success.
- **Q:** Keep both setup and explicit updates? **A:** No; fetching once after configuration
  removes the unconfigured early fetch and redundant index transfer.
- **Q:** Preserve arbitrary extra runner repositories? **A:** No; this job deliberately uses
  the canonical Hackage inventory, while scalar settings/cache paths remain intact. This
  configuration command is confined to disposable CI runners, not contributor machines.

## Referenced by

[[src/_MOC]] · [[Hackage Transport Delivery]] · [[Hackage Transport Test]]
