---
type: architecture
tags: [architecture, delivery]
aliases: [Engineering Delivery, Team Workflow]
---

# Engineering Delivery

## Branch Topology

```text
main                    production releases only; protected
  └─ dev                integrated next release; protected
      ├─ feature/<issue>-<slug>
      ├─ fix/<issue>-<slug>
      ├─ perf/<issue>-<slug>
      └─ docs/<issue>-<slug>

dev ──> release/<version> ──PR──> main ──annotated tag v<version>
                     └────fixes return to dev before promotion
```

- New work starts from a freshly fetched, fast-forwarded `dev`.
- One issue owns one independently testable vertical slice. Do not mix seams or unrelated compiler phases.
- Feature branches are short-lived and single-owner. Multiple agents may contribute only with explicit file ownership and handoffs.
- Direct commits to `dev` and `main` are prohibited after protection is enabled.
- Release branches contain versioning, changelog, compatibility/migration, and release-only fixes. Every release fix is first applied or immediately backported to `dev`.

## Issue Readiness

An issue is executable only when it contains:

- objective and user/language behavior;
- governing `[[wiki pages]]` and ADRs;
- in-scope and out-of-scope boundaries;
- acceptance criteria covering success, failure, regression, diagnostics, wiki parity, and full suite;
- risk/semantic compatibility classification;
- owning subsystem and role;
- dependencies and exact handoff entry point.

Architecture must be resolved in the vault before an issue is marked `ready`. Ambiguous semantic work is `design`, never handed to a Shadow as coding work.

## Team Roles

| Role | Primary ownership | Required review |
| --- | --- | --- |
| Language Architect | purpose, grammar, semantics, ADRs, cross-subsystem boundaries | semantic and compatibility changes |
| Frontend Engineer | source, lexer, parser, syntax recovery, formatter syntax model | frontend implementation |
| Semantic Engineer | resolution, types, traits, effects, exhaustiveness, ownership | semantic implementation |
| Runtime Engineer | interpreter, values, resource behavior, standard runtime | runtime implementation |
| Backend Engineer | Core IR lowering, C emission, target/runtime ABI, performance | backend and codegen |
| Tooling/Release Engineer | CLI, REPL, project/package model, diagnostics UX, CI/releases | tooling and promotion |
| Forensic Guardian | FMCF parity, backlinks, MOCs, changelog, handoffs | every PR before readiness |

One person or agent may fill multiple roles on a small project, but a PR author cannot be the sole code reviewer or semantic approver.

## Agent Construction Loop

1. **Architect agent:** reads the vault, grills the design, updates the governing page/ADR, and creates a DNA→Shadow handoff.
2. **Implementer agent:** owns an explicit file set, reads module and grammar pages completely, implements only specified behavior, and runs targeted gates.
3. **Independent reviewer agent:** receives the PR diff plus governing wiki pages, does not edit initially, and reports correctness, soundness, diagnostic, performance, and test defects by severity.
4. **Fix agent or original implementer:** resolves findings with focused commits and updated tests/wiki.
5. **Forensic Guardian agent:** audits 1:1 mirroring, page/code fidelity, backlinks, changelog, and handoff completeness.
6. **Release owner:** confirms checks/reviews and merges; no agent self-approves its own PR.

Agents working concurrently must own non-overlapping files or subsystems. Shared contracts are changed by the Architect first; downstream agents re-anchor to the new page after the contract handoff.

## Review Gates

Every PR must satisfy:

1. Linked issue; PR targets `dev` and uses `Closes #N`.
2. Review size target below 400 changed lines; split before 600 except isolated generated/snapshot data.
3. Semantic commits: `type(scope): imperative summary refs #N`.
4. FMCF: complete module pages existed first; wiki/code match; backlinks/MOCs/changelog updated.
5. Regression gate: success, failure, regression, and diagnostic/output checks; formatter/linter; full suite when practical.
6. Independent implementation review with no unresolved P0/P1 defects.
7. Language Architect approval when accepted syntax, meaning, diagnostic compatibility, Core IR contract, ABI, or public standard library API changes.
8. CI green on the supported GHC/toolchain matrix.

Review findings use:

- **P0:** security, data loss, memory unsafety, or release-blocking soundness defect.
- **P1:** incorrect accepted/rejected program, semantic divergence, crash, or broken public contract.
- **P2:** incomplete edge handling, misleading diagnostic, significant test/design debt.
- **P3:** maintainability or clarity improvement with no current behavior defect.

## Commit Mechanics

- Stage only the issue's files after reviewing `git status` and staged diff.
- Run targeted gates before each behavior commit and the full PR gate before review.
- Keep code, tests, and matching wiki delta together when separating them would create drift.
- No AI/assistant attribution, generic summaries, or unrelated cleanup.
- Prefer focused commits such as model → parser → diagnostics/tests when the PR remains coherent.

## Merge and History

- Use merge commits for feature PRs so the PR boundary and reviewed commit series remain visible.
- Delete merged remote feature branches.
- The linked issue receives the merged PR number and closes after merge.
- `dev` is always buildable. Failed integrations are fixed forward or reverted through a PR.
- Releases use `release/X.Y.Z`, a release PR to `main`, an annotated `vX.Y.Z` tag, and a back-merge to `dev` when release metadata differs.
- Semantic releases also update [[architecture/SEMANTICS#Revision Ledger]] and cite their ADRs.

## Scaling Rules

- Split ownership by subsystem, not compiler-layer microtasks that require constant shared edits.
- Stable phase contracts allow parallel teams; changing a shared contract freezes downstream merging until the handoff is accepted.
- Cross-subsystem issues identify a coordinating Architect and one integration owner.
- Add CODEOWNERS only when real maintainers exist; never invent reviewer identities.
- Promote [[Native Toolchain]] or another seam only from observed production variation, not team-count speculation.

## Current Repository Constraint

As of 2026-08-21 the GitHub repository has one administrator identity. CODEOWNERS records stewardship, but GitHub-native independent approval cannot be enforced until another maintainer identity exists. Until then, independent agent review is mandatory and preserved as a PR comment or check artifact; it supplements rather than impersonates human approval.

The local proposal, goal, and FMCF instruction files are a private input boundary. They remain gitignored and must never appear in issues, branches, commits, PRs, review comments, CI artifacts, or releases. Reviewers use the distilled vault specifications and ADRs.

## Grill Log

- **Q:** Should every agent get its own branch? **A:** One branch per issue, not per agent; agents contribute through explicit file ownership and handoffs. _Rationale:_ issue history stays coherent without branch explosion. _Rejected:_ nested agent branches for every task.
- **Q:** Should we squash all PRs? **A:** Preserve reviewed feature commits with a merge commit. _Rationale:_ compiler changes benefit from phase-by-phase historical bisectability. _Rejected:_ mandatory squash; unrestricted rebase merging.
- **Q:** Can the implementer agent review its own PR? **A:** It may self-audit but cannot be the sole independent reviewer. _Rationale:_ semantic blind spots need a fresh context. _Rejected:_ self-approval for speed.
- **Q:** Should semantic documentation update after code review? **A:** It exists before code and is reconciled during fixes. _Rationale:_ FMCF lock and history require design intent to precede implementation. _Rejected:_ retrospective spec writing.
- **Q:** Is `main` enough for a young project? **A:** Use `dev` now because the requested team/agent scaling and release promotion need a stable integration boundary. _Rationale:_ cheap to establish before parallel work. _Rejected:_ long-lived work directly against main.

## Referenced by

[[architecture/_MOC]] · [[FMCF Workflow]] · [[ADR-0004-team-delivery-and-agent-review]] · [[handoffs/_MOC]]
