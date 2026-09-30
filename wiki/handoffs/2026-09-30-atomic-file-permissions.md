---
type: handoff
tags: [handoff, runtime, stdlib, filesystem]
---

# Atomic File Permissions — Issue #385

## Scope and role transitions

Architect → Runtime/Standard Library Engineer: preserve ordinary creation permissions for
`Std.Fs.writeAtomically` and `writeTextAtomically`, and preserve existing destination permissions
when replacing a file. Standalone temporary files retain private creation permissions.

Implementation ownership covers the filesystem runtime operation, builtin name/type/effect
registration, `Std.Fs`, their mirrored pages, and a real CLI permission regression gate.
Independent review and Forensic Guardian parity audit belong to the integration owner.
The user explicitly authorizes direct commits and pushes to `dev`, issue closure, no PR, and no
waiting for hosted Actions. Fresh `dev` was fetched before work.

## Acceptance and resolved design

New files follow the process umask without changing that process-global setting. Replacements
copy platform-supported permissions before publication. Content staging is private; temporary
paths and handles are cleaned on failed writes, failed publication, and cancellation. Publication
remains a same-directory rename; this does not add crash-durability, ownership, or ACL guarantees.

Tests exercise text and bytes under umasks 022 and 077, existing restricted/group-readable/
executable modes, failure output and destination preservation, and private scratch-file creation.
Focused checks, Pudu formatting, warning-free optimized compilation, and the repository gates
must pass before publication.

## Independent review and validation

Runtime/Standard Library Engineer → Independent Runtime Reviewer/Language Architect:
reviewed retained handles, bracket acquisition and cleanup, IO-only failure handling,
umask-derived defaults, complete POSIX mode copying, symlink behavior, builtin registration,
and confinement admission. No blocking defects remain; public function signatures are stable.
The permission regression passes against the final optimized executable under both masks.
Cancellation cleanup follows bracket semantics; a deterministic cancellation injection is not
part of this focused gate. Pudu formatted `Std.Fs` before delivery.

Independent Reviewer → Forensic Guardian: mirrored pages, gate registration, backlinks,
MOCs, changelog, and private-file exclusion checked. Local toolchain is GHC 9.10.3.

## Completion

Complete: focused permission checks and every repository gate passed, including the clean
warning-free optimized build, full optimized suite, Pudu formatting, diagnostic identities,
API coverage, streaming residency, package workflows, scaffolding, lint, live LSP sessions,
editor robustness, watch behavior, and documentation parity. Independent review and vault
parity are resolved. No implementation work remains. Delivery is a direct `dev` commit and
push associated with #385, followed by issue closure without waiting for hosted Actions.

## Referenced by

[[handoffs/_MOC]] · [[Eval Io]] · [[Std Fs]] · [[Repository Gates]]
