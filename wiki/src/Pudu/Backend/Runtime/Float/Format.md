---
type: module
path: "@root/src/Pudu/Backend/Runtime/Float/Format.hs"
fidelity: Active
aliases: [Native Binary64 Formatter]
grammar: "[[grammar/haskell]]"
---
# Native Binary64 Formatter

## Purpose and interface

Export floatFormatRuntimeParts :: [(Text,[Text])] and
floatFormatRuntimeDependencies :: Text -> [Text]. Include the ordered natural
catalogue and its dependencies, then float_notice, float_require, float_decimal
and float_format. No source/Core/frame admission or runtime ABI revision yet.
The C interface size_t pudu_format_float64(uint64_t bits,char output[32]) writes
the GHC show spelling without requiring a terminator and returns at most 31
bytes, leaving room for the eventual printer's newline. Inputs are explicit
IEEE binary64 encodings, independent of host floating arithmetic and locale.

## Exact algorithm

Adapt locked GHC 9.14.1 floatToDigits/formatRealFloatAlt, preserving its strict
margins and tie decision. Decode fraction/exponent bits into the same adjusted
mantissa/exponent as GHC, including subnormals. Estimate decimal exponent from
floor(log2(value))*8651 quot 28738, adding one for nonnegative binary exponents;
C signed division must truncate toward zero. Fix up using exact r+mUp versus
10^k*s, scale through the checked natural kernel, and generate decimal digits
with exact remainder/margins. Stop on remainder<mDn or remainder+mUp>s; when
both hold, compare twice the remainder with s and round upward on equality.
Preserve asymmetric margins at normal powers of two, symmetric minimum-normal
margins and positive finite nonzero preconditions on the private decimal helper.

NaNs ignore sign/payload; infinities retain sign; negative zero prints -0.0.
Generic layout chooses exponent form only for decimal exponent e<0 or e>7,
prints exponent e-1 without a plus sign and always retains a fractional digit.
The locked example 0x44b52d02c7e14af6 prints 9.999999999999999e22. Float32 will
reuse this formatter on its widened normalized Double encoding.

Checked natural failures, invalid decimal-helper inputs, impossible digits or
capacity exhaustion are internal invariant failures, not silent truncation.
Twenty-four digit slots exceed the binary64 precision/interval bound; the
loose scaling/generation bound stays below 1210 bits, within the 1280-bit scratch.
Keep all generated writes within the 32-byte output contract. No allocation,
libc floating formatting, compiler integer extensions or host Double conversion.

## Notices and evidence

The GHC source anchor is blob 0e5883428bac63e22cab1d3143c801b25f315195 at the
[locked release](https://github.com/ghc/ghc/blob/ghc-9.14.1-release/libraries/ghc-internal/src/GHC/Internal/Float.hs).
Retain upstream attribution/conditions in [[Native Floating Notices]], source
package metadata, emitted adapted C and binary archives. Embed the notice as
compiler text, with no runtime file lookup; tests reject drift from the notice
artifact. The project's own license remains unchanged.

## Resolved Grill Log

- **Q:** Substitute another round-trip formatter? **A:** No; strict-margin choices and layout are observable.
- **Q:** Select GHC code without its notice? **A:** Adapted roots depend on float_notice, and archives retain the same artifact.
- **Q:** Admit Float32/Float64 from helper evidence? **A:** No; typed arithmetic, Core/frame integration and source differential tests follow separately.

## Dependencies and consumers

[[Native Floating Point]] · [[Native Floating Natural Kernel]] · [[Native Binary64 Formatter Tests]] · [[Native Floating Notices]]

## Referenced by

[[src/_MOC]] · [[Backend Module Map]] · [[Native Binary64 Formatter Delivery]]
