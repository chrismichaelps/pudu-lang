---
type: handoff
status: ACTIVE
issue: 460
tags: [application, runtime, tooling]
---
# Requested Issue Repairs

The maintainer requests production-quality repairs for #456 through #460. The #456 savepoint
repair is published as #461 with full local and hosted checks passing. The #462 admission
foundation is published as #463. Independent implementation and vault-parity review remain open.
The application maturity goal continues after these requested repairs.

Language Architect resolves bundle resolution and environment ownership in [[Compiler Library]],
[[Compiler Program]] and [[Pudu CLI]]. Tooling Engineer owns those modules, the complete bundle
gate, [[Bundle Environment Gate]], graph tests and their registration, with matching mirrors.
Work is sequential; preserve other work. Start #460 from freshly fetched development.
The existing executable entry exceeds the default size; this repair changes only bundle startup
and factors its existing run path. Extracting unrelated commands is outside this bounded repair.

Acceptance: exact absent, empty and supplied variable values; preserved relative-directory access;
cached and source-only execution; no host fallback; ignored unrelated manifests; ordinary discovery,
diagnostic refusal, artifact preservation, strict build, full compatibility and dependency checks.
All mirrors and resolved Grill Logs exist before implementation. No independent approval is claimed.

Issue #460 is ready on `feature/460-bundle-environment`, from development commit
`9aa340e29d5f20e82a175479c6d8dfe1c830f99a`. The original executable replaces all four tested variable
states with its private extraction path; the caller-directory marker remains readable. The repair
uses root-only resolution and preserves the original environment during execution.

The repair now runs in an attached isolated checkout after the shared checkout changed branches.
Only byte-verified owned changes were moved; unrelated website work was preserved. The modified
runtime fixture lost its executable signature: verification refused it, execution was terminated,
and refreshing that generated fixture restored execution. The gate preserves the changed digest.

Validation: strict optimized build, isolated-resolution regression, full compatibility suite and
complete bundle gate pass. Both cached and source-only bundles preserve absent, empty, unavailable
and spaced variable values and relative caller-directory access. Missing bundled imports remain
E2014 and malformed unrelated manifests are ignored. Fourteen graph regressions pass; application
graph has 215 modules, 96 closure members and no findings; native graph has 283 modules, 32 layers
and no import cycles. Fixture signatures and immediate artifact release resolve the observed gate
termination and disk exhaustion without dropping assertions. Independent review remains pending.

Exact next action: publish the validated #460 repair for independent review, then repair #459.

## Referenced by

[[handoffs/_MOC]] · [[Pudu CLI]] · [[Compiler Program]] · [[Application Maturity]]
