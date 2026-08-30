---
type: handoff
tags: [handoff, documentation, wiki, readme]
---

# Public Language Wiki Handoff

Issue #152 turns the governed vault into a reader-facing GitHub wiki and makes the repository
README a short entry point into that reference. The public wiki is a curated projection of current
implementation evidence; it does not replace [[grammar/pudu]] or [[architecture/SEMANTICS]] as the
normative engineering contract.

## FMCF role transition and ownership

The **Wiki/Documentation Author** owns the separate `pudu-lang.wiki` repository, `README.md`, this
handoff, the handoff map, and `wiki/CHANGELOG.md`. The role may read compiler, standard-library,
fixture, test, and vault evidence but changes no language implementation. Other repository work is
preserved.

An independent **Forensic Guardian** must review the public pages against the current compiler and
tests, reject any copied Meris-only claim, verify local and source links, and confirm the README is
shorter, removes its embedded program and Layout section, and points to the public reference.

## Active-agent ledger

| Agent | Issue | Role | Config | Worktree | Branch | Ownership | Avoid | Status |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `forensic_review_152` | #152 | Read-only Forensic Guardian | `~/.codex/config.toml` | read-only `/private/tmp/pudu-lang.wiki` and `/private/tmp/pudu-wiki-readme` | none | Public-wiki claims, links, examples, README/vault parity | All edits, commits, pushes, and unrelated worktrees | Complete: reviewed, safety-documentation defect corrected |

## Grill Log

- **Q:** Is the GitHub wiki the language specification? **A:** No. _Rationale:_ GitHub wiki pages
  optimize for readers and can omit internal proofs and delivery history; the versioned vault owns
  grammar and semantics. _Rejected:_ two normative specifications that can drift independently.
- **Q:** Should the Meris wiki pages be copied and renamed? **A:** No. _Rationale:_ Meris provides a
  useful definition-first page shape, but its JVM, server, package, interop, and maturity claims do
  not describe Pudu. Every Pudu claim must trace to Pudu code, tests, or the governed vault.
  _Rejected:_ mechanical brand substitution.
- **Q:** Should the README remain a second language tour? **A:** No. _Rationale:_ one concise
  repository entry point should state the project boundary, show build/install commands, and route
  readers to maintained reference pages. _Rejected:_ duplicating examples and feature prose that
  become stale outside the wiki.
- **Q:** Does the checker enforce comptime/unsafe transitively through higher-order calls? **A:** No.
  _Rationale:_ `checkComptimeCall` and `checkUnsafeCall` match only `NameExpression (name :| [])`;
  qualified names, aliases, and higher-order values fall through with `_ -> pure ()`. Runtime effect
  denial still prevents comptime violations at evaluation time, but the static check is direct-name-only.
  The grammar and Safety mirror now describe this boundary honestly. _Rejected:_ claiming transitive
  enforcement the implementation does not perform.

## Exact Next Action

~~Generate the public wiki pages from Pudu evidence, validate their links and examples, then update
the repository README and changelog before independent review.~~

Complete. Public wiki committed and pushed; repository branch committed on `feature/152-publish-language-wiki`
with README, vault updates, safety-documentation corrections, and this handoff.

## Referenced by

[[handoffs/_MOC]] · [[Pudu Language]] · [[Tooling]]
