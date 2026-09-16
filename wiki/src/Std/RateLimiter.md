---
type: module
path: "@root/lib/Std/RateLimiter.pudu"
fidelity: Active
tags: [module, stdlib, rate-limiter, token-bucket, traffic-shaping, fixed-point, low-level]
aliases: [Std RateLimiter]
---
# Std RateLimiter

## Purpose

Provide a high-throughput, deterministic token bucket rate limiter inspired by Java Guava (`RateLimiter`) and Haskell `token-bucket` (Hoogle / Hackage).
Implements a 64-bit fixed-point integer arithmetic token bucket ($2^{16} = 65536$ scaling factor) that eliminates slow floating-point operations and non-deterministic FPU rounding, enabling high-performance request throttling and traffic shaping.

## Interface

### Types
- `RateLimiter = { rateScaled: UInt64, burstScaled: UInt64, tokensScaled: UInt64, lastMicros: UInt64 }`: Fixed-point token bucket state.
- `AcquireResult = { limiter: RateLimiter, acquired: Bool }`: Result of a rate-limit check.

### Constructors
- `create(ratePerSec: Int, burstCapacity: Int) -> RateLimiter`: Allocates a token bucket initialized with full capacity at `burstCapacity` tokens and replenishing at `ratePerSec` tokens per second.

### Operations
- `tryAcquire(rl: &RateLimiter, tokens: Int, currentMicros: UInt64) -> AcquireResult`: Attempts to consume `tokens` at timestamp `currentMicros`. Returns updated state and `acquired: true` if tokens were available, or `acquired: false` and updated replenished state if budget was exceeded.
- `availableTokens(rl: &RateLimiter, currentMicros: UInt64) -> Int`: Computes the number of integral tokens currently available after replenishment.
- `reset(rl: &RateLimiter, currentMicros: UInt64) -> RateLimiter`: Resets tokens to maximum burst capacity at the given timestamp.

## Algorithm and boundaries

1. **64-bit Fixed-Point Scaling:**
   Tokens are stored as fixed-point 64-bit integers scaled by $\text{SCALE} = 65536$ ($2^{16}$):
   $$\text{ratePerMicro} = \frac{\text{ratePerSec} \times 65536}{1000000}$$
   $$\text{newTokens} = \Delta\mu s \times \text{ratePerMicro}$$
   All operations run as pure integer ALU instructions without FPU state switching.
2. **Saturating Accumulation:**
   Replenished tokens accumulate up to $\text{burstScaled}$ and saturate, preventing overflow or runaway token accumulation across long dormant intervals.
3. **Branchless Budget Test:**
   $$\text{if } \text{tokensScaled} \ge \text{costScaled} \implies \text{tokensScaled} \mathrel{-=} \text{costScaled}, \quad \text{acquired} = \text{true}$$

## Grill Log

- **Q:** Why use fixed-point arithmetic instead of `Float`?
  **A:** Floating-point numbers introduce platform-dependent rounding, NaN/Infinity propagation risks, and expensive FP register saving during context switches. Fixed-point integer arithmetic executes in standard CPU integer registers, guaranteeing exact deterministic behavior across all hardware architectures.
- **Q:** What is the timestamp resolution?
  **A:** Timestamps are given in microseconds (`UInt64`), providing fine-grained sub-millisecond rate limiting capable of handling tens of thousands of requests per second.

## Referenced by

[[src/Std/_MOC]] · [[Std Http Server]] · [[architecture/STDLIB]]
