---
type: module
path: "@root/src/Pudu/Backend/Runtime/Kernel/Url.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
aliases: [Native URL Kernel]
---
# Native URL Kernel

Percent-encodes a `Str` for use as a URL component in one pass, serving the `urlEncodeComponent` builtin.

The kernel first counts the bytes that must be escaped, so the common case returns the input itself and the escaping case allocates the result once at its final length.

## Contract

- `pudu_url_encode(text)` takes the text and returns a `Str`.
- A byte is escaped when it is not an unreserved byte. Unreserved bytes are the ASCII letters, the digits, `-`, `_`, `.` and `~`; they are written as themselves.
- Every other byte of the UTF-8 encoding is written as `%` followed by two upper-case hexadecimal digits.
- When no byte needs escaping, the input text is returned retained, with no allocation.
- Otherwise one buffer of the exact final length is allocated and filled in a single forward pass.
- The part is named `url_encode`; `urlKernelParts` includes it only in programs that call the builtin.

## Resolved Grill Log

Why a kernel: the library version pushed one escape text per byte into an array and joined it, about 7% of the website module page's CPU; returning unchanged text without allocating keeps the common case free. The escape count is taken first, so the escaping case allocates once at its final length.

## Referenced by

[[Native Kernel Runtime]] · [[Eval Url Encode]]
