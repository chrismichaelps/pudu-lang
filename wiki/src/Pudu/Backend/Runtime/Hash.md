---
type: module
path: "@root/src/Pudu/Backend/Runtime/Hash.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
aliases: [Native Hash Mixing]
---
# Native Hash Mixing

Export hashRuntimeParts and hashRuntimeDependencies.

| Part | Provides |
| --- | --- |
| hash_step | the 64-bit basis and one multiply-and-xor step |
| hash_text | the walk over a text's or byte view's bytes |
| hash_int | a magnitude's bytes from its highest non-zero one, then the sign |
| hash_wide | the same over a two-word magnitude |
| hash_big | the same over BigInt limbs; zero is one zero byte |
| mix_hash | the per-process seed and the store index |

`mix_hash`:
`pudu_mix_seed` reads eight bytes from the system random source on first use
and keeps them; `pudu_mix_hash` xors the operand's low word with the seed,
runs the three-step 64-bit finalizer the interpreter runs, and answers the
unsigned word as an Int.

## Resolved Grill Log

Read `/dev/urandom` with the descriptor calls the runtime already includes;
a short or failed read, and every Windows build, uses the interpreter's
fixed constant. A map whose placement is guessable still works; one that
refuses to start does not. The seed is process state, not a value: nothing
releases it.

## Referenced by

[[Backend Frame Program]] · [[Native Runtime Dependencies]] · [[Native Indexed Stores]]
