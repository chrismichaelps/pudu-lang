---
type: module
path: "@root/lib/Std/SipHash.pudu"
fidelity: Active
tags: [module, stdlib, siphash, hash, keyed-hash, dos-protection, arx, low-level]
aliases: [Std SipHash]
---
# Std SipHash

## Purpose

Provide a high-speed, cryptographically strong keyed PRF / hash function implementing SipHash-2-4, inspired by Haskell `siphash` (Hoogle / Hackage) and Linux kernel/Rust standard hash maps.
Operates on four 64-bit state words using fast Add-Rotate-Xor (ARX) rounds in CPU registers, delivering high throughput while protecting hash tables and network tokens against HashDoS collision attacks.

## Interface

### Types
- `SipKey = { k0: UInt64, k1: UInt64 }`: 128-bit secret key.

### Constructors
- `key(k0: UInt64, k1: UInt64) -> SipKey`: Creates a 128-bit key.
- `keyFromBytes(bytes: &Array[UInt8]) -> Option[SipKey]`: Parses a 16-byte array into two 64-bit little-endian words.

### Hashing Functions
- `sipHash24(k: &SipKey, bytes: &Array[UInt8]) -> UInt64`: Computes the 64-bit SipHash-2-4 digest for `bytes` using key `k`.
- `sipHash24Text(k: &SipKey, text: Str) -> UInt64`: Computes 64-bit SipHash-2-4 directly over UTF-8 text string bytes.
- `sipHash24Int(k: &SipKey, value: Int) -> UInt64`: Computes SipHash-2-4 directly over a single 64-bit integer without allocating byte arrays.
- `sipRound(v0: &mut UInt64, v1: &mut UInt64, v2: &mut UInt64, v3: &mut UInt64)`: Executes one ARX compression round.

## Algorithm and boundaries

1. **Initialization:**
   State words are initialized with standard cryptographic constants XORed with the key:
   $$v_0 = k_0 \oplus \text{0x736f6d6570736575u64}$$
   $$v_1 = k_1 \oplus \text{0x646f72616e646f6du64}$$
   $$v_2 = k_0 \oplus \text{0x6c7967656e657261u64}$$
   $$v_3 = k_1 \oplus \text{0x7465646279746573u64}$$
2. **SipRound (ARX):**
   $$v_0 \mathrel{\&+}= v_1; \quad v_2 \mathrel{\&+}= v_3$$
   $$v_1 = \text{rotL}(v_1, 13); \quad v_3 = \text{rotL}(v_3, 16)$$
   $$v_1 \oplus= v_0; \quad v_3 \oplus= v_2$$
   $$v_0 = \text{rotL}(v_0, 32)$$
   $$v_2 \mathrel{\&+}= v_1; \quad v_0 \mathrel{\&+}= v_3$$
   $$v_1 = \text{rotL}(v_1, 17); \quad v_3 = \text{rotL}(v_3, 21)$$
   $$v_1 \oplus= v_2; \quad v_3 \oplus= v_0$$
   $$v_2 = \text{rotL}(v_2, 32)$$
3. **2-4 Scheduling:**
   Each 64-bit word runs 2 compression rounds. The final block embeds the total input length modulo 256, followed by 4 finalization rounds with $v_2 \oplus= \text{0xFF}$.

## Grill Log

- **Q:** Why SipHash-2-4 over MurmurHash3 for hash tables?
  **A:** MurmurHash3 is not collision-resistant against deliberate adversarial multicollision attacks (HashDoS), allowing attackers to degrade hash tables to $O(N^2)$ via carefully chosen colliding keys. SipHash-2-4 uses a 128-bit secret key to make collision generation computationally infeasible ($2^{64}$ complexity).
- **Q:** Does SipHash require hardware cryptographic accelerators (e.g. AES-NI)?
  **A:** No, SipHash uses only basic integer additions, XORs, and rotations, executing in single-digit nanoseconds on standard general-purpose ALU cores.

## Referenced by

[[src/Std/_MOC]] · [[Std HashMap]] · [[Std Bytes]] · [[architecture/STDLIB]]
