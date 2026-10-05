---
type: handoff
status: COMPLETE
tags: [handoff, regression, checker, runtime, stdlib]
---

# Production Bug Repairs

## Objective and delivery

Repair issues #371, #372, #373, #376, #377, #378, #379, #381, #382, #383, and #384.
The user explicitly requests one commit per completed issue directly on `dev`, with Pudu
formatting before each commit and no PR. That instruction overrides the ordinary branch/PR
workflow for this batch. Private governance inputs remain ignored and excluded.

## Role transitions and ownership

Language Architect → Runtime Engineer: Decimal dispatch and nested equality, evaluator modules
and focused runtime tests. Language Architect → Semantic Engineer: alias formation and module
isolation, imported constants, match coverage, and Option method diagnostics, with disjoint
formation, folding, exhaustiveness, and method-test ownership. Language Architect → Standard
Library Engineer: YAML compact sequences, quoted scalars, and block scalars in issue order.
Each implementation returns to independent Language Architect and Forensic Guardian review
before the Tooling/Release Engineer formats, validates, and commits its exact owned files.
Shared test harness and MOC/changelog integration belong to the delivery owner.

## Acceptance and risks

Preserve canonical module identities, transparent aliases, compile-time effect denial, closed
match completeness, numerical Decimal equality at every nesting level, and typed YAML refusal.
Add success/failure/regression/output evidence, preserve formatter stability, and run the full
suite and warning gates. Independent reviewers cannot author the implementation they approve.

## Completed delivery

All eleven fixes were committed separately on `dev`, formatted with Pudu where applicable,
and pushed after integrating the five concurrent upstream commits without discarding changes.
The eleven GitHub issues are closed as completed. No PR was created and no GitHub Actions
completion was awaited.

| Issue | Commit | Evidence |
| --- | --- | --- |
| #371 | `4af50f5d` | Decimal direct, generic, qualified, missing-method and rendering checks |
| #372 | `27dd0338` | Imported late/chained generic callback aliases, execution and E3001 refusal |
| #373 | `74deadb9` | Imported constants, selected builtin-name shadowing, cache reuse and IO refusal |
| #376 | `02983000` | Nested numerical equality, retained scale, unequal values and collection lookup |
| #377 | `1403bdc9` | Correlated Option/Bool products, guards, alternatives and missing combinations |
| #378 | `8e0e1ef6` | Canonical nested constructors, Json graph order and instantiated payloads |
| #379 | `48f1c62a` | Actual HTTP server with package alias, two traversal orders and wrong-type refusal |
| #381 | `8de2249f` | Exact compact-list trees, siblings, depth boundary and tab refusal |
| #382 | `6ee97e53` | YAML escapes, doubled quotes, delimiter scans and malformed Unicode refusals |
| #383 | `e2bd8397` | Exact unwrapOr E3005 with/without imports and qualified Some/None success |
| #384 | `d521673c` | Physical scalar content, paragraphs, siblings, chomping and indentation refusals |

## Final validation

`PUDU_LIB` pointed to this checkout. `bash test/gates.sh` passed every gate after the integration:
clean optimized compilation with `-Werror`, complete optimized suite, formatting of every committed
Pudu source, diagnostic-code uniqueness, release planning, API coverage and documentation,
streaming residency, package install/publish workflows, generated projects, lint, language-server
sessions and robustness, watched reloads and documentation-site parity. The local toolchain was
GHC 9.10.3; the hosted toolchain matrix was not awaited. Independent implementation and wiki
reviews were completed, with the reported bounds, scope and test-registration findings resolved.
New module and handoff wiki links resolve, and private governance inputs remain untracked.

## Exact next action

None; this issue batch is complete.

## Referenced by

[[handoffs/_MOC]] · [[CHANGELOG]]
