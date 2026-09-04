# Contributing to Pudu

Pudu is developed as a language specification and compiler together. The FMCF vault is normative: read `wiki/00-INDEX.md`, `wiki/architecture/SEMANTICS.md`, and `wiki/architecture/DELIVERY.md` before proposing language or compiler changes.

The local files `fmcf.md`, `lang_proposal.md`, and `goal.md` are private inputs. Never stage, commit, quote, attach, or reproduce them in issues, PRs, diagnostics, artifacts, or release notes. Public work cites the distilled vault pages and ADRs.

## Running the gates locally

```bash
bash test/gates.sh
```

Runs what CI runs, in CI's order, and names the gate that failed.

The warning gate forces recompilation, and that is not incidental. A fresh
checkout cannot be up to date, so CI's warning gate always compiles; locally
`cabal` frequently answers "Up to date" after a source has changed, and a
warning gate that did not compile reports a clean tree while checking none of
it. That has hidden real errors in this repository more than once. Forcing the
rebuild costs a few minutes and buys an answer worth having.

## Starting work

1. Select or create one ready GitHub issue with a bounded vertical slice.
2. Confirm the governing wiki module/semantic pages and ADR are complete.
3. Fetch and fast-forward `dev`.
4. Create `feature/<issue>-<slug>` (or `fix/`, `perf/`, `docs/` as appropriate) from `dev`.
5. Keep the branch focused on that issue.

An issue is ready only when its behavior, risks, acceptance criteria, test obligations, and wiki links are resolved. Architecture questions are settled in the vault before implementation.

## Changes and commits

- Keep implementation files under 500 lines by default.
- Target fewer than 400 changed lines per PR and split before 600 unless excess is isolated generated or snapshot data.
- Use semantic commits such as `feat(parser): parse guarded match arms refs #42`.
- Keep code, tests, and matching wiki changes synchronized.
- Do not add generated authorship or assistant attribution.

## Verification

Every feature proves:

- valid behavior;
- invalid behavior;
- the regression risk that could return;
- diagnostic code/span or user-facing output when applicable;
- formatter/linter stability;
- full-suite compatibility when practical.

Compiler changes also cover the affected lexer/parser/AST/type/ownership/exhaustiveness/backend/CLI layers. Native features compare interpreter and compiled behavior where applicable.

## Review

Open a PR to `dev` with `Closes #<issue>`; mandatory intermediate size partitions use `Refs #<issue>`, keep it open, and name the exact remaining action. Explain behavior, reviewability, validation, and deferred boundaries concisely.

The author performs a self-audit, then an independent reviewer checks correctness, semantic conformance, diagnostics, performance risks, and test strength. Semantic, ABI, or public API changes require Language Architect approval. A Forensic Guardian confirms wiki/source parity and history updates.

Review findings use P0 through P3 severity as defined in `wiki/architecture/DELIVERY.md`. P0/P1 findings block merge. With only one GitHub identity, independent agent review must be preserved in a PR comment or CI artifact; native approval enforcement requires another maintainer account.

## Merge and release

Feature PRs use merge commits so reviewed intermediate commits remain bisectable, then delete the feature branch. `dev` must remain buildable.

Releases branch as `release/X.Y.Z` from `dev`, promote by PR to `main`, receive annotated tag `vX.Y.Z`, and synchronize any release-only metadata back to `dev`. Semantic releases update the semantic revision ledger and cite their ADRs.
