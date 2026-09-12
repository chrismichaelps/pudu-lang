---
type: module
path: "@root/packages/pudu/v0.1/lib/Std/Fs.pudu"
fidelity: Active
domain: "[[Standard Library]]"
subsystem: "[[architecture/STDLIB]]"
grammar: "[[grammar/pudu]]"
tags: [module, stdlib, filesystem, safety]
aliases: [Std Fs]
---

# Std Fs

## Purpose and interface

The filesystem operations whose safety depends on doing them in one step. `rename` replaces a path;
`writeAtomically` and `writeTextAtomically` replace a file's contents so no reader sees them half written;
`temporaryFileIn`, `temporaryDirectoryIn`, and `withTemporaryDirectory` create uniquely named scratch
space; `removeTree` removes a tree without following links; `permissions`, `setPermissions`, and
`metadata` read and change what a path permits and what it is; `linkTo` creates a symbolic link;
`canonical` resolves links; and `resolveInside` refuses a path whose real location leaves a base.
`FsError` carries an `Io.IoError` for operating-system refusals, `OutsideBase` for containment, and
`NamesExhausted` when every temporary name tried was taken.

## Governance and algorithm

**Replacement is a rename.** `writeAtomically` writes the bytes to a new file created beside the
destination under a name the operating system chose and claimed in the same step, then renames that file
over the destination. On one filesystem a rename leaves the destination naming the old contents or the
new, never a mixture, so a crash before the rename keeps the old file and a crash after it keeps the new
one. A failed write or rename removes the staged file. Durability across power loss additionally needs
the data flushed to the device, which the runtime does not yet expose; the guarantee here is against
torn and partially visible writes.

**A temporary name is claimed by creating it.** A temporary file is named and created exclusively by the
operating system, as the prefix, random digits, and `.tmp`, so a prefix containing a dot is preserved. A temporary directory is created with a random sixteen-digit suffix from the secure
random source, and creation fails when the name exists, so the attempt itself claims the name; a
collision tries another name, up to sixteen times. Nothing checks a name and then uses it, so there is no
window for another process to take it.

**Cleanup is scoped.** `withTemporaryDirectory` removes its directory after the action whether the action
succeeded or failed, and reports the action's own failure first.

**Links are removed, not followed.** `removeTree` asks whether each path is itself a symbolic link before
descending; a link is removed as a link, so removing a tree containing a link to elsewhere removes only
the link.

**Containment is decided on real locations.** `resolveInside` resolves both the base and the joined path
through every link and relative step before comparing them with `Std.Path.isInside`. A name that reads as
inside but resolves elsewhere is refused, and a path that does not exist is refused because it has no
real location to compare.

**Permissions are the portable four.** Readable, writable, executable, and searchable are the questions
every supported operating system answers; a numeric mode would claim owner, group, and other on systems
that have none of them.

`Std.Io.copy` now copies bytes rather than decoding text, and `Std.Io.move` renames, falling back to copy
and remove only when a rename cannot reach the destination.

## Grill Log

- **Q:** Check whether a temporary name is free, then create it? **A:** No. _Rationale:_ the gap between
  the check and the creation is where another process takes the name. _Rejected:_ check-then-create;
  creation itself claims the name.
- **Q:** Expose Unix mode bits? **A:** No. _Rationale:_ they do not mean the same thing everywhere.
  _Rejected:_ octal modes in the portable API.
- **Q:** Decide containment from path spelling? **A:** No. _Rationale:_ a symbolic link inside the base can
  point anywhere. _Rejected:_ lexical containment for filesystem access; `Std.Path.isInside` remains the
  lexical question.
- **Q:** Follow links while removing a tree? **A:** No. _Rationale:_ a link to a home directory inside a
  scratch tree would take the home directory with it. _Rejected:_ following removal.

Resolved Grill Log: replacement by rename, names claimed by creation, scoped cleanup, non-following removal,
real-location containment, and portable permissions.

## Referenced by

Depends on [[Std Bytes]], [[Std Env]], [[Std Io]], and [[Std Path]].

Consumed by [[Uses Fs]] and [[Runtime Evaluation Spec]].

[[src/Std/_MOC]] · [[First Release Readiness]]
