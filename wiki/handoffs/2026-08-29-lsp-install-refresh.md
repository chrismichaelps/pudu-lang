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

## Active-agent ledger

| Agent | Issue | Role | Config | Worktree | Branch | Ownership | Avoid | Status |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `forensic_review_150` | #150 | Read-only Forensic Guardian | `~/.codex/config.toml` | read-only `/private/tmp/pudu-lsp-install` | none | Independent diff and vault-parity review | All edits, commits, pushes, and unrelated worktrees | Complete — clear, no findings |

## Grill Log

- **Q:** Should the extension gain its own syntax checker? **A:** No; strengthen the real server
  session. _Rationale:_ `pudu lsp` is deliberately the compiler, and a second checker recreates the
  drift this issue is removing. _Rejected:_ editor-only parsing or diagnostic suppression.
- **Q:** Is `pudu version` enough after reinstalling? **A:** No. _Rationale:_ current development
  builds all report `0.1.0.0`, so only checking the recent source and running an LSP session proves
  which behavior was installed. _Rejected:_ timestamps or version text as semantic evidence.

## Exact Next Action

Push `feature/150-sync-lsp-install` and open its PR to `dev`, then require the GitHub run to finish
green without the retired Node 20 action annotation before merge.

## Validation evidence

- Both unoptimized and optimized full test runners pass after the issue #147 merge; both strict
  builds compile and link under `-Werror` (the sandbox only denies Cabal's final global build-log
  write).
- Every committed Pudu fixture passes `fmt --check`; diagnostic-code integrity and documentation
  site parity pass, including both documentation CLI failure paths.
- The optimized worktree binary and refreshed `~/.local/bin/pudu` each check
  `RecentLanguage.pudu` without diagnostics and complete the real two-document stdio session with
  `recentDiagnostics: 0`.
- The refresh instructions put `~/.local/bin` first on `PATH` and assert the resolved executable
  before either behavioral proof, preventing an older earlier entry from satisfying the checks.
- Independent Forensic Guardian review cleared the complete 171-addition diff with no findings and
  confirmed mirror parity, backlinks, resolved Grill decisions, private-boundary compliance, and
  the sub-400-line review size.

## Referenced by

[[handoffs/_MOC]] · [[Language Server]] · [[Pudu CLI]] · [[Tooling]]
