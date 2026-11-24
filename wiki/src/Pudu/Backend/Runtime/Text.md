---
type: module
path: "@root/src/Pudu/Backend/Runtime/Text.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
aliases: [Native Text Runtime]
---
# Native Text Runtime

## Purpose and interface

Export textRuntimeParts :: [(Text, [Text])] and textRuntimeDependencies ::
Text -> [Text], published through [[Backend Runtime]] and
[[Native Runtime Dependencies]].

`pudu_text` is `{const unsigned char *bytes; size_t length; pudu_text_owner *owner;}`.
An owner is `{size_t count; unsigned char bytes[];}`. Parts:

| Part | Provides |
| --- | --- |
| text | the two types and `pudu_text_release` |
| text_retain | `pudu_text_retain`, selected with the frame engine for any program with text |
| text_literal | `pudu_text_literal(bytes, length)` over static bytes |
| text_allocate | `pudu_text_allocate(length, &bytes)`, the one allocation path |
| text_copy | `pudu_text_copy(bytes, length)` for rendered scratch buffers |
| text_concat | `pudu_text_concat(left, right)`; an empty side retains the other |
| text_compare | `pudu_text_compare(left, right)` as -1/0/1 by bytes, then length |
| text_show | `pudu_text_show(text)`: quotes plus the `\\` `\"` `\t` `\n` escapes |
| text_display_int / text_display_wide / text_display_float | decimal or locked GHC float text |
| print_text | bytes, newline, one flush |

Every function returning `pudu_text` returns a reference the caller owns;
arguments are borrowed. Size arithmetic is checked before allocating, and an
allocation failure is `pudu_memory_failure`, the interpreter's message.

## Negative logic

No NUL-terminated strings: lengths are explicit, so `\0` survives. No libc
locale or formatting for floats (the #509 formatter writes the bytes). No
interning or sharing that could make two values alias mutable state; text is
never mutated after it is filled.

## Resolved Grill Log for #935

The allocator bounds the complete C object, including its owner header,
by `PTRDIFF_MAX`. Text operations still report their own length refusal
before allocation when their language-level limit is exceeded.

Resolved Grill Log: the fallible allocation helper returns a null owner on
failure so the JSON reader can release partial values before reporting a
host failure. Other callers use the reporting wrapper.

Resolved Grill Log: copying zero or one byte can use stable immutable
storage. All 256 single-byte values are available, including zero and bytes
that belong to byte sequences. Writable allocation and longer copies keep
their original ownership contract.

Resolved Grill Log: two decimal digits can use a compact immutable table.
Copies and concatenations share it, including retained slices of the result.
Concatenating consecutive views of the same heap owner retains that owner
once and extends the view. Empty views keep no reference to their source.

## Grill Log

- **Q:** Why does `pudu_fail_text` copy the message? **A:** Frame cleanup runs before printing and may release the text the message came from (#525).

- **Q:** Why a view instead of a pointer to one block? **A:** Literals need no
  allocation, and the coming `drop`/`take`/`slice` must share their source the
  way Data.Text slices do, keeping the cost of a scan proportional to what it
  moves. _Rejected:_ copying on every slice.
- **Q:** Why plain counts instead of atomics? **A:** Native programs are single
  threaded until tasks are admitted; that slice must revisit this.
- **Q:** Why does `print_text` ignore write errors? **A:** It remains a legacy
  printer for isolated IR paths. Source output uses the Result-valued adapter
  in [[Native Output Results]]; entry output uses its separate builder path.

## Dependencies and consumers

[[Backend Runtime]] · [[Native Runtime Dependencies]] · [[Native Binary64 Formatter]] · [[Backend Frame Values]]

## Computed help (#558)

`fail_text_help` copies both the message and the help before cleanup runs,
then reports with the help in place of the site's.

## Referenced by

[[src/_MOC]] · [[src/Pudu/Backend/_MOC]] · [[Native Emission Coverage]]

## Diagnostic ownership (#570)

Resolved Grill Log: Transfer the copied allocation from fail_text/fail_text_help into the terminating reporter. Static help stays borrowed; computed help shares the one owned base. Check combined payload length before allocation. See [[Native Diagnostic Ownership]].

## Caller failures (#631)

fail_text_caller copies the caller's site, swaps in its own code and help, and
reports through pudu_fail_text. A NULL caller aborts: no frame entered
without a value call reaches a builtin body.
Resolved Grill Log: the copy keeps the static site table read-only.

An empty message skips the copy and reports with no payload.
Resolved Grill Log: GCC 15 warned about the uninitialized one-byte copy once
the empty text was folded; there is nothing to keep alive. (#633)

## Owned text slot helpers (#821)

TEXT slot stores and moves have separate runtime roots. The store accepts an
already-evaluated owned text, releases the previous owner and transfers the
new reference into the slot. The move snapshots the source, empties it and
uses the same store. A self-move preserves the reference.

Resolved Grill Log: the stored expression is a C function argument. It
completes before the helper can release the destination, including when it
reads the destination. Computing a slot address has no side effect.
