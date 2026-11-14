---
type: module
path: "@root/test/Pudu/Backend/TextCaseSpec.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
aliases: [Backend Text Case Tests]
---
# Backend Text Case Tests

## Purpose and interface

Export textCaseProperties with two groups.

1. A C program built from the [[Native Text Case]] parts converts every
   scalar with toUpper and toLower and trims it; it prints each scalar that
   changes (with the result's UTF-8 bytes) and each scalar trim removes. The
   output must equal the same listing computed with Data.Text and isSpace in
   the test process, which links the same text as pudu.
2. The linked Data.Text converts a string of every scalar, and final-sigma and
   dotted-I samples, exactly as the concatenation of per-scalar conversions.
   If a future text release adds context rules, this fails before native
   can disagree.

## Grill Log

- **Q:** Why compare in the test process rather than with a script? **A:** The
  test binary links the cabal-resolved text-2.1.4; GHC's boot text-2.1.3
  answers differently, so a global script would check the wrong library.

## Referenced by

[[Native Text Case]] · [[src/_MOC]]
