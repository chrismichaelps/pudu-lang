---
type: handoff
tags: [handoff, tooling, lsp, installation, ci]
---

# LSP and Installation Refresh Handoff

Issue #150 closes the gap between a correct worktree compiler and the older executable an editor
may still resolve. It also removes the Node 20 deprecation annotation exposed by the clean issue
#148 CI run.

## FMCF role transition and ownership

The **Tooling/Release Engineer** owns `.github/workflows/ci.yml`, `README.md`,
`editors/vscode/README.md`, `test/lsp-session.mjs`, the tooling/LSP/CLI vault pages, this handoff,
and the changelog. The work changes no Pudu syntax or meaning; it makes existing semantics part of
the installed editor compatibility contract. Other repository work is preserved.

The compatibility source covers `if let`, `let … else`, `while let`, postfix `?`, and the
`Never`-preserving diverging branch from issue #146. Issue #147 must therefore merge into `dev`
before final validation and delivery.

An independent **Forensic Guardian** must verify that the stdio session really requires a clean
diagnostic publication for every recent form, the refresh command replaces the resolved binary,
the action majors match the official releases, and CI finishes without the Node 20 annotation.

## Grill Log

- **Q:** Should the extension gain its own syntax checker? **A:** No; strengthen the real server
  session. _Rationale:_ `pudu lsp` is deliberately the compiler, and a second checker recreates the
  drift this issue is removing. _Rejected:_ editor-only parsing or diagnostic suppression.
- **Q:** Is `pudu version` enough after reinstalling? **A:** No. _Rationale:_ current development
  builds all report `0.1.0.0`, so only checking the recent source and running an LSP session proves
  which behavior was installed. _Rejected:_ timestamps or version text as semantic evidence.

## Exact Next Action

Commit the recent-surface fixture, refresh instructions, and official action upgrades; merge the
now-landed issue #147 from `dev`; then validate the worktree and installed executable before
independent review and a PR to `dev`.

## Referenced by

[[handoffs/_MOC]] · [[Language Server]] · [[Pudu CLI]] · [[Tooling]]
