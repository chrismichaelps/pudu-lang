---
type: module
path: "@root/src/Pudu/Backend/Runtime/Kernel/Http.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
aliases: [Native HTTP Header Kernel]
---
# Native HTTP Header Kernel

Splits a request head's header lines into `(name, value)` pairs in one pass, serving the `httpHeaderPairs` builtin and the header reads of `Std.Http.Message`.

The part is `http_header_pairs`. It needs the array, text, text view, text trim and memory failure parts, and nothing else.

## Contract

- `pudu_http_header_pairs(head, pair)` takes the head text and the program's own pair constructor, and returns an array of pairs.
- The request line is skipped. The remaining lines are split at the head's own line breaks: `\r\n` when the head contains one, otherwise `\n`.
- A header line is taken when its name is a token (ASCII letters, digits, and `!#$%&'*+-.^_`|~`, at least one of them) followed by a colon. Its value is the rest of the line, trimmed.
- A line beginning with a space or tab, a line still holding a carriage return or line feed, a line with no colon, and a name that is not a token are each not taken whole. Any one of them makes the kernel answer an empty array.
- A head with no header line also answers an empty array.
- The lines are walked twice: a first pass only counts them, then the array is allocated at that count and a second pass writes the pairs into it.

## Resolved Grill Log

Why an empty array as the refusal: the kernel never decides that a head is malformed. A head it cannot take whole goes back to the Pudu reader in `Std.Http.Message`, which reports the bad line, so the kernel and the reader cannot disagree about what counts as a valid header.

Why two passes: the count fixes the array's final length, so nothing is reallocated while pairs are written, and the pair maker is called once per taken line.

Why the pair maker is a parameter: the pair's layout belongs to the program, so the kernel receives the constructor from emission and never builds a layout of its own.

## Referenced by

[[Native Kernel Runtime]] · [[Eval Http Headers]] · [[Std Http Message]]
