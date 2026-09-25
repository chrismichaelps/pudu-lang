---
type: module
path: "@root/test-fixtures/stdlib/UsesFs.pudu"
fidelity: Active
domain: "[[Testing]]"
subsystem: "[[architecture/DELIVERY]]"
tags: [module, fixture, stdlib, filesystem]
aliases: [Uses Fs]
---

# Uses Fs

## Purpose and interface

Executable Pudu fixture for filesystem safety, run entirely inside temporary directories it creates and
removes. Its `main` returns 19 held assertions.

Names and replacement: two temporary directories get distinct prefixed names; atomic replacement leaves
only the destination in its directory; replacement into a missing directory is refused and creates
nothing; a temporary file is created empty with its prefix; a rename replaces the destination and removes
the source; renaming a missing path is refused.

What paths are: a written file reports its size and permissions; a directory reports itself; read-only
permissions round-trip and are restored; a canonical path resolves a `.` step; a missing path has no
canonical form.

Containment and removal: a file inside a base resolves; `..` is refused; a symbolic link inside the base
that points outside is refused; removing the base removes the link and leaves its target untouched; a
scoped temporary directory is gone after its action succeeds and after it fails; a temporary directory in
a missing parent is refused; and the fixture's own directory is removed at the end.

## Referenced by

[[Std Fs]] · [[Runtime Evaluation Spec]]
