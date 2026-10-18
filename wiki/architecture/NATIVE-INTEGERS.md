---
type: architecture
tags: [architecture, native, integers]
aliases: [Exact Native Integer Carriers]
---
# Exact Native Integer Carriers

## Status and observed requirement

Resolved local design for issue #498; production implementation and independent
architecture/implementation/wiki review remain pending. This page does not claim
completed emission coverage. [[Native Emission Coverage]] remains authoritative.

The existing checker accepts a positive 2^63 literal through some blocks and
inferred locals when a later negation settles its constraint. The interpreter
retains that mathematical value until use. An int64_t carrier cannot preserve
it. The temporary native refusal prevents narrowing, but successful execution
of these accepted programs is still required. Changing their checker/interpreter
meaning to fit the backend is outside this repair.

## Representation and phase boundary

Use an internal C value containing uint64_t magnitude and a negative flag.
Canonical zero has magnitude zero and a clear flag. The carrier retains positive
2^63 as distinct from negative 2^63. Normal platform Int values keep their
existing mathematical meaning and target width. Internal carrier size is not
Pudu's declared type width or a public FFI layout promise.

Checked literal admission remains explicit. Initially admit canonical platform
Int magnitudes through 2^63, including its deferred positive boundary. Future
signed/unsigned kinds through 64 bits can use the same magnitude carrier with
separate canonical limits. Int128, UInt128 and BigInt still need wider/exact
representations. No silent truncation, implicit kind conversion or display-name
matching is permitted.

A generated kind descriptor carries positive/negative magnitude limits, width
and signedness. Ordinary operations check their result at the points where the
interpreter checks; locals, branches, parameters and returns preserve values
without inserting a new runtime bound check. This distinction is observable
for the accepted deferred literal. Preserve canonical IntegerKind throughout
Core, source provenance and diagnostic-site construction.

## Arithmetic algorithms

- Addition with equal signs adds unsigned magnitudes and records carry before
  selecting checked failure or saturation. Opposite signs subtract the smaller
  magnitude from the larger and retain the larger operand's sign.
- Subtraction uses mathematical sign reversal of the second operand inside the
  addition kernel, without invoking checked unary negation first.
- Multiplication multiplies unsigned magnitudes and detects overflow with
  nonzero divisor and UINT64_MAX / magnitude. Its result sign is the operand
  sign difference. Unsigned overflow is defined; a carry is never interpreted
  as a successful checked result.
- Checked result settlement refuses carry or magnitude beyond the declared
  sign-specific limit, using the original operation's E7005 site. Saturation
  clamps to that sign's declared endpoint before normalizing zero. Preserve
  sign through an overflow whose low magnitude bits happen to be zero.
- Division/remainder use unsigned magnitude division after the existing zero
  check. Quotient sign differs when operand signs differ; remainder keeps the
  dividend sign. Only quotient settlement applies the interpreter's checked
  result bound. This distinguishes negative MIN / -1 from positive 2^63 / -1.
- Unary negation flips sign and performs checked result settlement. Comparison
  reads actual signs/magnitudes, not wrapped bit patterns. Deferred positive
  2^63 therefore orders above every ordinary Int rather than becoming MIN.

## Bits, shifts and rendering

Convert a negative value to its unsigned bit pattern by unsigned subtraction
from zero. Wrap to the declared width with an unsigned mask. Decode a signed
high bit into a negative magnitude using unsigned arithmetic; never narrow an
out-of-range unsigned number to a signed C type.

Bitwise and wrapping operations work on these bit patterns and decode the
result at the declared kind. Shift count validation uses the count value's
actual sign and magnitude before any C shift. Negative versus width failures
retain distinct E7004 sites. Signed right shifts fill sign bits according to
the actual value's negative flag, not merely a high bit on a deferred positive
magnitude. Count zero still performs the interpreter's final kind wrapping;
positive 2^63 >> 0 consequently becomes MIN. Guard zero before any width-minus-
count sign-fill shift. All C counts stay below 64.

Print the sign explicitly and the unsigned magnitude through PRIu64, preserving
bytes, line endings and flushing. Entry status uses zero, sign and magnitude to
retain the existing 0/1..255 clamp. Bool and unit keep their current ABI.

## Emission and module obligations

The private generated-function ABI changes with runtime revision 4. Integer
parameters/results/locals/temporaries use the exact carrier; C call wrappers
retain depth timing and operand sequencing. Comparisons call the integer
comparison helper while Bool/unit comparisons retain their existing forms.

Audit every universal C zero: result slots, joins, loop breaks, return paths,
Never operands, declarations and call arguments. A numeric zero needs a typed
carrier initializer; Never carries no value even though C still type-checks
unreachable statements. Keep unit sentinels and runtime depth counters separate.

Split runtime ownership into value/conversion, arithmetic and bit-operation
modules under Runtime.Integer, with a small catalogue/dependency interface.
Publish complete mirrored pages before changing those implementation files.
Runtime selection closes the fixed dependency graph in deterministic order;
only required static helpers are emitted. Existing failure rendering, shared
messages and exact Pudu spans remain unchanged.

## Evidence and remaining verification

A local standalone C11/UBSan prototype compared 19,980 boundary and seeded
full-width cases against independent mathematical formulas, including positive
2^63 intermediates, all three arithmetic policies, shifts, complement, division,
remainder and comparison. The handoff retains the local probe paths. This experiment is local evidence,
not production implementation, committed regression coverage or a formal proof
over all inputs.

Production acceptance still requires tree/compiled/native equality for block,
local, mutation, parameter, return, print and entry-status cases; existing
Never/loop/call-depth/unit/operator diagnostics; ordinary and deferred boundary
matrices with independent expectations; strict C11 warning checks; full gates;
platform CI; and independent review. Measure representative native loops/calls
before promotion to identify the cost of the internal ABI change.

## Resolved Grill Log

- **Q:** Reject accepted source permanently or change the oracle? **A:** Neither satisfies #498; preserve its existing observable behavior with an exact carrier.
- **Q:** Rely on C signed overflow, high unsigned casts or arithmetic right shift? **A:** No; unsigned magnitude/bit algorithms and explicit sign handling define each operation.
- **Q:** Check every stored value against Int bounds? **A:** That would change deferred-intermediate behavior. Apply checks at the interpreter's operation boundaries.
- **Q:** Make this a one-off positive-MIN tag? **A:** Use a reusable sign/magnitude carrier and kind limits, preparing ordinary signed/unsigned widths without a second exceptional arithmetic engine.
- **Q:** Does the prototype finish numeric coverage? **A:** No; production integration, wider families, host boundaries and complete validation remain open.

## Dependencies and consumers

[[Native Emission Coverage]] · [[Native C11 Backend Delivery]] · [[Pudu Core]] ·
[[Compiler Lower Body]] · [[Compiler Lower Scalar]] · [[Backend Runtime Integer]] ·
[[Backend Emit]] · [[Diagnostic Arithmetic]]

## Referenced by

[[architecture/_MOC]] · [[Native Emission Coverage]] · [[Native C11 Backend Delivery]]
