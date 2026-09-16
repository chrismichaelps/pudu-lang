---
type: adr
status: ACCEPTED
date: 2026-08-21
decision_risk: 0.3
review_date: 2026-10-01
tags: [adr]
aliases: [ADR-0004-team-delivery-and-agent-review]
---

# ADR-0004 — Team Delivery and Agent Review

## Context

Pudu must start with delivery mechanics that support a small team now and multiple compiler specialists/agents later without losing semantic intent or review accountability.

## Problem

Ad hoc commits to `main`, large horizontal PRs, self-reviewing agents, and conversation-only handoffs would make language semantics and compiler defects difficult to audit or scale.

## Decision

Adopt [[Engineering Delivery]]: target protected `main`/`dev`, issue-linked vertical feature branches, semantic commits, small PRs to `dev`, independent implementation review, architecture approval for semantic/public changes, FMCF Guardian parity review, and explicit release branches/tags.

## Rationale

The flow makes the issue, vault, branch, commits, PR, reviews, tests, and release tag one traceable chain while allowing specialists to work in parallel behind stable phase contracts.

## Consequences

- Initial repository bootstrap must establish `dev` before normal feature work.
- GitHub issue/branch automation should enforce naming and references without hiding dirty worktrees.
- CI arrives with the issue #2 executable scaffold; branch protection is enabled when repository ownership can satisfy the review rules without bypassing them. Both are required before production claims.
- Agent roles are responsibilities, not fake identities or approval substitutes.

## Alternatives

- **Trunk-only main:** rejected for the requested multi-agent integration/release separation.
- **Git Flow with long-lived release/hotfix complexity:** rejected as excessive before regular releases.
- **One branch per agent:** rejected because ownership should follow features and review units.
- **Fully autonomous self-merge:** rejected because independent review is a semantic safety boundary.

## Validation

- First three features must each trace issue → wiki → branch → commits → PR → independent review → merged `dev`.
- PRs target under 400 changed lines and carry explicit focused/full validation evidence. Issue #1 is the single governance-bootstrap exception: its cross-linked vault, workflow, and semantic constitution land atomically before implementation, and its independent review must explicitly accept that exception.
- Review 2026-10-01 for wait time, PR size, escaped defects, and handoff quality.

## Referenced by

[[decisions/_MOC]] · [[Engineering Delivery]] · [[CHANGELOG]]
