---
type: module
path: "@root/lib/Std/BloomFilter.pudu"
fidelity: Active
tags: [module, stdlib, probabilistic, bloomfilter, data-structures]
aliases: [Std BloomFilter]
---
# Std BloomFilter

## Purpose

Provide a space-efficient probabilistic set with zero false negatives (100% recall) and mathematically controlled false-positive probability.
Essential for caches (mitigating cache penetration), database LSM storage engines, spellcheckers, and distributed deduplication.
Inspired by Guava `BloomFilter`, `java.util.concurrent`, and Haskell `bloomfilter`.

## Interface

### Types
- `BloomFilter`: An immutable probabilistic set holding bit configuration, optimal hash count, and bit storage.

### Constructors
- `create(bitCount: Int, hashCount: Int) -> BloomFilter`: Low-level constructor specifying raw bit size and hash function count.
- `optimal(expectedItems: Int, falsePositiveRate: Float) -> BloomFilter`: High-level mathematical constructor computing optimal bit size $m$ and hash count $k$ from capacity and tolerance.

### Membership Operations
- `insert(filter: &BloomFilter, item: Str) -> BloomFilter`: Inserts a string item, returning an updated filter.
- `insertBytes(filter: &BloomFilter, item: &Bytes) -> BloomFilter`: Inserts raw bytes, returning an updated filter.
- `contains(filter: &BloomFilter, item: Str) -> Bool`: Tests if item may be present (true $\implies$ possibly present; false $\implies$ definitely absent).
- `containsBytes(filter: &BloomFilter, item: &Bytes) -> Bool`: Tests if raw bytes may be present.

### Algebraic Operations & Inspection
- `merge(a: &BloomFilter, b: &BloomFilter) -> Option[BloomFilter]`: Computes the set union of two compatible filters via bitwise OR. Returns `None` if dimensions differ.
- `intersect(a: &BloomFilter, b: &BloomFilter) -> Option[BloomFilter]`: Computes the set intersection of two compatible filters via bitwise AND.
- `bitCount(filter: &BloomFilter) -> Int`: Total number of bits allocated.
- `hashCount(filter: &BloomFilter) -> Int`: Number of independent hash functions used per item.
- `estimatedCount(filter: &BloomFilter) -> Int`: Approximates the number of distinct inserted items using bit occupancy.

## Algorithm and boundaries

Kirsch-Mitzenmacher double-hashing generates $k$ simulated hash positions from two 32-bit hash components ($h_1, h_2$) derived from FNV-1a and Murmur-style mixing:
$$g_i(x) = (h_1(x) + i \cdot h_2(x)) \pmod m$$
This achieves identical asymptotic collision resistance to $k$ independent hash functions while executing in $O(1)$ constant time with zero heap allocations.
The mathematical bounds follow:
$$m = -\frac{n \ln p}{(\ln 2)^2}, \quad k = \frac{m}{n} \ln 2$$
False negative rate is strictly 0.0%: a query returning `false` guarantees with 100% mathematical certainty that the element was never inserted.

## Grill Log

- **Q:** Why Kirsch-Mitzenmacher double-hashing instead of running $k$ separate cryptographic hashes?
  **A:** Cryptographic hashes (SHA-256) are orders of magnitude slower and unnecessary for probabilistic set membership. Double hashing provides uniform bit distribution with minimal CPU cycles.
- **Q:** Why immutable filter return values?
  **A:** Preserves Pudu's functional value semantics and guarantees thread-safe, race-free sharing across concurrent workers.

## Referenced by

[[src/Std/_MOC]] · [[Std BitSet]] · [[architecture/STDLIB]]
