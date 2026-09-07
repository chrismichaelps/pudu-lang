---
type: handoff
tags: [handoff, tooling, lsp, editor, extension]
---

# Complete LSP Capabilities and Editor Extension Handoff

Issue #198 restores editor LSP functionality and completes standard language server capabilities across bounded modules: references, rename, document highlight, semantic tokens, signature help, inlay hints, workspace symbols, code actions, and contextual member completions.

## FMCF role transition and ownership

The **Tooling/LSP Engineer** owns `src/Pudu/Lsp/*`, `wiki/src/Pudu/Lsp/*`, `editors/vscode/*`, `test/Pudu/Lsp/ServerSpec.hs`, `test/lsp-session.mjs`, this handoff, and `wiki/CHANGELOG.md`.

An independent **Forensic Guardian** must verify that:
1. Every new submodule under `src/Pudu/Lsp/` is strictly `< 500 lines`.
2. Every implementation file has an exact mirrored page under `wiki/src/Pudu/Lsp/` with a resolved Grill Log.
3. The editor extension (`pudu-lang.pudu-0.3.0`) contains all required runtime dependencies (`vscode-languageclient`, `vscode-languageserver-protocol`, `vscode-jsonrpc`).
4. All quality gates in `test/gates.sh` pass cleanly under `-O2` and `-Werror`.

## Active-agent ledger

| Agent | Issue | Role | Config | Worktree | Branch | Ownership | Avoid | Status |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `lsp_complete_198` | #198 | Tooling / LSP Engineer | default | workspace | `dev` | `src/Pudu/Lsp/*`, `wiki/src/Pudu/Lsp/*`, `editors/vscode/*`, `test/Pudu/Lsp/*`, `test/lsp-session.mjs` | Unrelated compiler passes | Complete — all gates passing |

## Grill Log

- **Q:** Why did the extension crash on launch in VS Code / Antigravity IDE? **A:** The extension package at `~/.antigravity-ide/extensions/pudu-lang.pudu-0.2.0/node_modules/` omitted transitive dependencies `vscode-languageserver-protocol` and `vscode-jsonrpc`, causing Node to throw `MODULE_NOT_FOUND` before `pudu lsp` was spawned. _Resolution:_ Flat bundle deployment with version bump to `0.3.0`.
- **Q:** Why did multi-directory project imports fail? **A:** `Pudu.Lsp.Server` previously derived workspace root from the directory of each opened document rather than walking up the tree to project markers (`pudu.cabal`, `pudu.toml`, `.git`, `lib`). _Resolution:_ Captured `rootUri`/`workspaceFolders` during `initialize` and implemented recursive upward traversal in `Pudu.Lsp.Documents`.
- **Q:** Should all capabilities live in `Server.hs`? **A:** No. `Server.hs` was already ~450 lines; putting capabilities in `Server.hs` would violate the 500-line limit. Each capability is isolated into its own focused submodule (`References.hs`, `Rename.hs`, `Highlight.hs`, `SemanticTokens.hs`, `SignatureHelp.hs`, `InlayHints.hs`, `WorkspaceSymbols.hs`, `CodeAction.hs`, `Completion.hs`).

## Exact Next Action

Stage all changes on `dev`, push, and open the PR for review.

## Validation evidence

- Full test gates pass:
  - `no warnings, optimized` (0 errors under `-Werror -O2`).
  - `full suite, optimized` (all QuickCheck properties pass with 200 tests each).
  - `every committed Pudu file is formatted` (`fmt --check` clean).
  - `the language server answers a real session` (`lsp-session.mjs` validates all 12 capabilities).
  - `the language server survives what an editor sends it` (`lsp-robustness.mjs` clean).
  - `the documentation site keeps its contract`.
