---
type: module
path: "@root/lib/Std/Base32.pudu"
fidelity: Active
domain: "[[Pudu Program]]"
subsystem: "[[Standard Library]]"
grammar: "[[grammar/pudu]]"
tags: [module, stdlib, encoding, bytes]
aliases: [Std Base32]
---

# Std Base32

## Purpose and interface

Bytes written in one case with no punctuation, for secrets, DNS labels, file names on
case-folding systems, and codes people read aloud.

- `type Base32Error = InvalidCharacter(Char, Int) | BadLength(Int) | NonZeroTrailingBits`;
  `explain(problem) -> Str`.
- `encode`, `encodeUnpadded`, `decode` — RFC 4648 standard alphabet.
- `encodeHex`, `decodeHex` — RFC 4648 extended-hex, whose text sorts like its bytes.
- `encodeCrockford`, `decodeCrockford` — Crockford's alphabet without `I`, `L`, `O`, `U`.

## Semantics

- Encoding cuts the bytes into five-bit digits, completing the last with zero bits; the standard and
  hex forms pad with `=` to a multiple of eight digits, `encodeUnpadded` and Crockford do not.
- Decoding accepts either case, padded or not; only trailing `=` is padding, and one elsewhere is an
  invalid character. Lengths whose remainder mod 8 is 1, 3, or 6 spell no byte count and are
  refused; non-zero leftover bits are refused because no encoder writes them.
- Crockford decoding removes hyphens and reads `I`/`L` as `1` and `O` as `0`; `U` is refused.
- Digit tables are `Map` constants folded at compile time; the accumulator holds at most twelve bits.

## Grill Log

- **Q:** Accept altered trailing bits as the `Std.App.Totp` reader does? **A:** No. _Rationale:_ two
  texts decoding to the same bytes make the text a poor identifier and hide truncation. _Rejected:_
  leniency here; Totp keeps its own reader for pasted secrets.
- **Q:** One function with an alphabet parameter? **A:** Named pairs. _Rationale:_ the alphabet is
  the format, and a call should say which it writes. _Rejected:_ an `Alphabet` sum.
- **Q:** Crockford's optional check symbol? **A:** Not included. _Rationale:_ no fixed width is
  agreed; [[Std Checksum]] covers integrity where needed.

## Dependencies and consumers

- Prelude only. Reached by [[Uses Base32 Pem All]].

## Referenced by

[[src/Std/_MOC]] · [[architecture/STDLIB]] · [[Uses Base32 Pem All]]
