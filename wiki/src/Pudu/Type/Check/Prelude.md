---
type: module
path: "@root/src/Pudu/Type/Check/Prelude.hs"
fidelity: Active
domain: "[[Pudu Type]]"
subsystem: "[[Semantics]]"
grammar: "[[grammar/haskell]]"
depth_score: 0.3
depth_status: SHALLOW
coupling: 2.0
interface_stability: 0.9
tags: [module, shallow]
aliases: [Type Check Prelude]
---

# Type Check Prelude

## Purpose

The names a program has without declaring them: the constructors every program can write, and the signature of every effect the prelude provides.

## Interface

```haskell
declareBuiltinConstructors :: Checker ()
effectSignatures           :: [(Text, Scheme)]
```

### Governance

- **A table rather than a rule.** Nothing here decides anything; it states what the language already has.
- That is why it depends on nothing in checking and nothing in checking reaches back into it — which made this the one cut in the checker that needed no capability at all.
- Every effect answers with `Result[T, Str]` rather than failing, so a missing file is an outcome a caller handles rather than something that stops the program.
- Existing TCP/TLS effects retain their original signatures; separately named `Within` connect,
  send, receive, and TLS-close signatures carry the millisecond operation timeout consumed by the
  runtime boundary. `Std.Net` and `Std.Tls` own the typed public spelling.

### Linkage

- **Requires:** [[Type Env]], [[Type Value]].
- **Consumed by:** [[Type Check Method]].

## Grill Log

- **Q:** Replace the original network signatures with timeout parameters? **A:** No. _Rationale:_
  existing source must retain its original effect ABI; separately named `Within` effects carry the
  new argument. _Rejected:_ an arity-breaking replacement.

## Referenced by

[[src/Pudu/Type/_MOC]]

## Word-map cardinality kernel

`wordMapPopCount[K](Map[K, UInt64]) -> UInt128` is a pure wired-in reduction consumed by
[[Std BitSet]]. It counts payload bits independently of keys, including zero payloads, and avoids
entry-array materialization. The runtime checks UInt64 kind/range before conversion and reports
E7001 for invalid payloads or receiver, E7003 for wrong arity. Registration covers semantic names,
type signatures, installation, builtin naming and pure dispatch. No IO or FFI capability is required.

Resolved Grill Log: Use an explicit primitive rather than recognize a library function by name,
so shadowing and ordinary calls retain their meaning. Result width is UInt128; an Int-sized host
map cannot contain enough 64-bit words to overflow it. This remains unvalidated.
