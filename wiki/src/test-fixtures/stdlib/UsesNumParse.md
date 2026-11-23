---
type: module
path: "@root/test-fixtures/stdlib/UsesNumParse.pudu"
fidelity: Active
tags: [module, fixture, stdlib, numeric, parse]
aliases: [Uses Num Parse]
---

# Uses Num Parse

## Purpose and interface

Stdlib fixture for integer parsing: `parseInt` and `parseIntIn` of [[Std Num]]. Its entry `main` runs the parser on text that is valid, empty, malformed, at the edges of `Int`, and in other radixes, and answers the number of checks that held. The data spec `test/Pudu/Compiler/Program/Eval/DataSpec.hs` asserts that count, which is `11`.

Checks, one per `if` of `main`:
1. Decimal with a sign: `42` is 42, `-42` is -42, and `+7` is 7.
2. Zero and leading zeros: `0`, `-0` and `007` read as 0, 0 and 7.
3. Empty text, a lone sign and a lone `+` answer `None`.
4. A space before, a space after, an underscore separator, a stray letter, and a double sign answer `None`.
5. The largest `Int` reads exactly; one past it answers `None`.
6. The smallest `Int` reads exactly; one below it answers `None`.
7. Text far beyond the `Int` range in either direction answers `None`.
8. Radix 16 with `ff` and `FF` is 255, and radix 2 with `-101` is -5.
9. Radix 36 with `z` is 35; a digit outside the radix (`8` in radix 8) and a letter outside it (`g` in radix 16) answer `None`.
10. A radix of 1 or 37 answers `None`; the largest `Int` in hex (`7fffffffffffffff`) reads exactly.
11. The smallest `Int` in hex (`-8000000000000000`) reads exactly; `8000000000000000` without a sign answers `None`.

## Invariants

- Each check compares an exact `Option` value, so a wrong sign, digit or bound fails the check.
- The fixture makes no foreign call and starts no host. It runs interpreted and as native C11 code, and both must agree.

## Negative Logic

- No stop on bad text. Every malformed input answers `None` and the program continues.
- No locale, no decimal point and no whitespace trimming. Those are the caller's rules, as [[Std Text]] states for its own readers.

## Dependencies and consumers

Depends on [[Std Num]]. Its checks mirror the contract that [[Std Text]], [[Std Cron]], [[Std Ui Desktop]] and [[Std Ui Accessible]] rely on when they read numbers through the shared parser. The example that reads a stored count with the same parser is [[Vault Example]].

## Resolved Grill Log

- **Q:** Why check both Int extremes one step past each end? **A:** A parser that accumulates in the wrong sign overflows silently at one of them. Checking the value and its neighbour outside the range shows both edges are exact.
- **Q:** Why check the most negative value in hex? **A:** Its magnitude is one more than the largest positive value. A parser that negates after accumulating the magnitude fails there first, so it is the sharpest single check of the sign handling.
- **Q:** Why are the radix bounds checked at both ends? **A:** A radix of 1 or 37 has no digits to read. Answering `None` for both keeps an out-of-range request from producing a value of any kind.

## Referenced by

[[src/_MOC]] · [[Std Num]] · [[Std Text]] · [[Std Cron]] · [[Std Ui Desktop]] · [[Std Ui Accessible]] · [[Vault Example]] · [[980-storage]]
