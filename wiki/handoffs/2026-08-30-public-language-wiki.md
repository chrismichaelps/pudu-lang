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
| `forensic_guardian_152` | #152 | Read-only Forensic Guardian | inherited | read-only `/private/tmp/pudu-lang-wiki-book` and `/private/tmp/pudu-wiki-readme` | none | Public claims, links, examples, prose, README/vault parity | All edits, commits, pushes, and unrelated worktrees | Complete: clear after compiler-backed corrections |
| `language_architect_152` | #152 | Read-only Language Architect | role-enforced | expired temporary checkouts | none | Public semantic accuracy and design/implementation boundaries | All edits, commits, pushes, and unrelated worktrees | Ended without a review result |
| `root` | #152 | Language Architect | primary session | `/private/tmp/pudu-wiki-delivery` and `/private/tmp/pudu-wiki-publish` | `feature/152-publish-language-wiki` / wiki `master` | Final semantic review and delivery | Language implementation and unrelated branches | Complete: current behavior checked against evaluator, checker, resolver, tests, and stdlib |

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
- **Q:** Can an alternation bind the same name on both sides today? **A:** The language rule says it
  must, but the current resolver reports the repeated binder as a duplicate declaration. The public
  book shows a binding-free alternative and records binder-carrying alternatives as an open compiler
  defect. _Rejected:_ teaching intended syntax as usable when the shipped checker rejects it.
- **Q:** How is example validity established? **A:** Nine complete modules covering values,
  records/sums/tuples, pattern matching, loops, failure propagation, sets, tasks, compile-time work,
  and references pass both the installed `pudu fmt --check` and `pudu check`. The macro example
  passes `pudu check`; it is not counted among the nine because the current formatter changes
  `twice!(2)` to `twice !(2)`. Illustrative fragments are not labelled complete programs.
  _Rejected:_ treating plausible syntax highlighting as validation.
- **Q:** Did the public semantic review rely on the prose reviewing itself? **A:** No. The Language
  Architect pass traced task ordering to `Eval.Call`, compile-time limits to `Eval.Loop` and
  `Eval.Env`, direct-name capability enforcement to `Type.Check.Safety`, alternation behavior to
  `Semantic.Resolve` and `Type.Check.Pattern`, and set claims to `Std.Set`. The independently run
  Forensic Guardian review remained a separate clear gate. _Rejected:_ treating an unavailable
  reviewer result as approval.

## Exact Next Action

~~Generate the public wiki pages from Pudu evidence, validate their links and examples, then update
the repository README and changelog before independent review.~~

The reconstructed and revalidated 27-page book is published at wiki commit `db8bb8a`. Push the
rebased repository branch, open the issue #152 PR, wait for CI, merge to `dev`, comment on the
issue, and close it.

Validation already run:

- `pudu fmt --check` and `pudu check` over nine extracted complete wiki example modules:
  `comptime`, `data`, `loops`, `reference`, `result`, `set`, `state`, `task`, and `values`.
- Local wiki link checker: 27 pages, no broken local links.
- GitHub source-link check through `gh api` against `dev`: README, grammar, semantics, VS Code,
  standard library, tests, fixtures, and vault paths all resolve.
- `git diff --check` for the repository branch and public wiki checkout.
- `cabal test all --test-show-details=direct` from the rebased branch: pass.

## Referenced by

[[handoffs/_MOC]] / [[Pudu Language]] / [[Tooling]]
