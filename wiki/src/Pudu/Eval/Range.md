---
type: module
path: "@root/src/Pudu/Eval/Range.hs"
fidelity: Active
domain: "[[Pudu Program]]"
subsystem: "[[Runtime]]"
grammar: "[[grammar/haskell]]"
depth_score: 0.6
depth_status: MEDIUM
coupling: 0.6
interface_stability: 0.8
tags: [module, medium]
aliases: [Eval Range]
---

# Eval Range

## Purpose

Say what a range is at run time, and answer what can be asked of one. A range holds two ends and a
rule for reading them rather than the values between them, so everything here is arithmetic until a
caller asks for the values themselves.

## Interface

### Signatures

```haskell
rangeMethods :: [(Text, RangeMethod)]
rangeLength :: Value -> Maybe Integer
rangeElements :: Value -> Maybe [Integer]
rangeBounds :: Span -> Value -> Int -> Evaluator (Int, Int)
renderRange :: Maybe Integer -> Bool -> Maybe Integer -> Text
callRangeMethod
  :: (Span -> Value -> [Value] -> Evaluator Value)
  -> Span -> RangeMethod -> Value -> [Value] -> Evaluator Value
-- the value itself is declared in [[Eval Value]]:
-- RangeValue !(Maybe Integer) !Bool !(Maybe Integer)
```

### Governance

- **A range is its ends, never the values between them.** `0..1_000_000` is three fields. Building
  the list it stands for would allocate a million boxed values before the first one is read, which is
  the difference between a loop that starts and one that allocates first. `rangeElements` is lazy, so
  a caller that stops early — a `for` that breaks, a `first` — pays only for what it read.
- **Either end may be absent**, and an absent end means "as far as the thing this is applied to
  goes". Nothing here can know that, so `rangeBounds` is the one place absence is answered, and it is
  given the length of the value being sliced. Every other method that needs a number where there is
  none is refused by name with `E7004` rather than guessing one.
- **A slice is required to lie within the value, and to be in order.** A clamped slice hands back a
  different sequence than the one that was asked for and hides the arithmetic that produced the
  bounds, so a range past the end is `E7004` where it was written.
- **`length` and `contains` are computed, not counted.** They are subtraction and comparison whatever
  lies between the ends, so they answer in the same time for three values and for three billion.
- **The method set is closed.** That is what lets [[Type Check Rule]] type each one exactly and
  report an unknown one against the range rather than dispatching it.
- **Everything that skips or reverses answers with an array.** A range counts upward by one; a
  reversed or stepped sequence is not a range, and calling it one would leave `contains` and `length`
  claiming things that are no longer true of it.
- **The walking methods are given the evaluator's own application** rather than calling closures
  themselves, so a literal written in the language is called exactly as any other call calls it.

### Linkage

- **Requires:** [[Eval Value]], [[Eval Env]], [[Source]].
- **Consumed by:** [[Eval Operator Access]] (indexing and members), [[Eval Call]] (method dispatch),
  [[Eval Loop]] (iteration), [[Evaluator]].

## Algorithm

Arithmetic on two `Maybe Integer` ends and an inclusivity flag. `rangeElements` builds Haskell's own
lazy enumeration, which the loop consumes one cell at a time; `rangeBounds` resolves the absent ends
against a supplied length and answers the half-open `(from, count)` pair that `Seq`, `Text`, and
`ByteString` slicing take.

## Negative Logic (Prohibited Paths)

- No materialising a range to answer a question arithmetic can answer.
- No clamping a slice to the value it is applied to.
- No default for an absent end anywhere but `rangeBounds`, which is given the length to use.
- No negative or zero step, which would either never finish or count the wrong way.

## Edge Cases

- A range whose end is below its start covers nothing rather than a negative count.
- `..` with both ends absent is the whole of whatever it is applied to, and is a legal value on its
  own; `..=` with no end is refused by the parser, since an inclusive end that is not written
  includes nothing in particular.

## Depth

DEPTH 0.60 (MEDIUM). Two ends, one rule, and one place that answers what is missing.

## Grill Log

- **Q:** Why is a range not simply the array it stands for, as it was before? **A:** Because it was
  built eagerly, and `for i in 0..20_000_000` allocated twenty million values to count to twenty
  million. Residency is now flat across two orders of magnitude of range length. _Rejected:_ keeping
  the tuple and bounding its size, which would make the same expression legal or not depending on a
  number nobody wrote.
- **Q:** Should a slice clamp to the value instead of reporting? **A:** No. _Rationale:_ the bounds
  are usually computed, and a clamp turns arithmetic that was wrong into a sequence that is merely
  shorter — discovered much later, somewhere else. _Rejected:_ a clamping `slice` beside a reporting
  one, which is two answers to one question.
- **Q:** Why do `reverse` and `step` answer with an array rather than a range? **A:** Because a range
  counts upward by one, and a value that does not cannot answer `contains` or `length` the way a
  range does. _Deferred:_ a strided range type, if one is ever needed for more than these two
  methods.
- **Q:** Should ranges carry an integer width, so `0u8..10u8` is a `Range[UInt8]`? **A:** Not now.
  _Rationale:_ a range's ends are checked at `Int`, which is the type an index is and therefore the
  type a range is useful at; carrying a width would spread that decision through slicing and
  iteration for a case nothing here needs yet. _Deferred:_ revisit when an unsigned index exists.

## Referenced by

[[src/Pudu/Eval/_MOC]] · [[Eval Operator Access]] · [[Eval Loop]] · [[Eval Call]]
