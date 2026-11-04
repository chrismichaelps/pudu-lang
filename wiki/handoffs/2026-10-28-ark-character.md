---
type: handoff
status: ACTIVE
aliases: [Ark Character Delivery]
tags: [handoff, ark, physics]
---
# Ark Character Delivery

Issue #714 starts from freshly fetched dev on feature/714-capsule-movement. Scope ownership:
Ark/Physics/Character.pudu, UsesArkCharacter.pudu, ark-character.mjs, CI/local gate registration
and their vault mirrors, plus CharacterBench.pudu and its mirror. Preserve the separate engine
integration checkout and all other work.

Role transition: Architect resolved [[Ark Character Movement]] before implementation; Runtime
Engineer owns the implementation and focused checks. Independent implementation, Language
Architect and Forensic Guardian review remain required before PR readiness; self-audit is not
independent approval. Work proceeds without delegated agents as requested.

The installed executable was older than the integration checkout. Its optimized compiler rebuilt
successfully with -Werror; validation uses explicit binaries and checkout-specific library roots.
Reference study covered continuous movement, sliding, corner response and support classification;
no external code is imported. This slice deliberately defines its own bounded geometry contract.

Focused behavior, formatter, lint, positioned E3001 and source-archive checks pass on both the
installed compiler and the optimized integration compiler. The clean branch build passes -Werror;
the complete repository gate passes, including full optimized suite, formatting, packages,
streaming residency, live tooling, documentation and API coverage (zero undocumented exports).
[[Ark Character Benchmark]] consumes a three-contact workload after a separate warmup. Three
optimized interpreter runs measured 1,022, 1,032 and 1,042 ms per 1,000 moves (median 1.032 ms
per move), with the same consumed checksum. Boundary preparation is included; native execution
and broad scene acceleration remain performance obligations.

Implementation commit `05793025` is pushed. Draft PR [#715](https://github.com/chrismichaelps/pudu-lang/pull/715)
targets dev; hosted checks are running and the required independent reviews remain pending.
The complete change stays below the 600-line delivery limit. No PR is merged.

Exact next action: specify finite-obstacle capsule sweep and walking/falling policy contracts
in the vault before extending the movement implementation.

## Referenced by

[[handoffs/_MOC]] · [[Ark Engine]] · [[Ark Character Movement]]
