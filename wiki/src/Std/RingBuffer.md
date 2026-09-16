---
type: module
path: "@root/lib/Std/RingBuffer.pudu"
fidelity: Active
tags: [module, stdlib, ringbuffer, circular-buffer, queue, fifo, low-level, data-structures]
aliases: [Std RingBuffer]
---
# Std RingBuffer

## Purpose

Provide a bounded, power-of-two circular FIFO ring buffer inspired by Haskell `Data.RingBuffer` (Hoogle / Hackage) and lock-free systems programming.
Replaces expensive hardware modulus/division instructions (`%`) with single-cycle bitwise masking (`& (capacity - 1)`), providing deterministic $O(1)$ push, pop, and peek operations without heap churn.

## Interface

### Types
- `RingBuffer = { buffer: Array[Option[Int]], head: Int, tail: Int, count: Int, capacity: Int, mask: Int }`: Circular buffer state.
- `PopResult = { buffer: RingBuffer, item: Int }`: Returned value and updated buffer state from `pop`.

### Constructors
- `create(minCapacity: Int) -> RingBuffer`: Creates a ring buffer whose capacity is rounded up to the nearest power of two (minimum 4).

### Operations
- `push(rb: &RingBuffer, item: Int) -> Option[RingBuffer]`: Appends `item` to the tail of the buffer in $O(1)$ time. Returns `None` if the buffer is full.
- `pop(rb: &RingBuffer) -> Option[{ buffer: RingBuffer, item: Int }]`: Removes and returns the item from the head of the buffer in $O(1)$ time. Returns `None` if the buffer is empty.
- `peek(rb: &RingBuffer) -> Option[Int]`: Returns the item at the head without removing it in $O(1)$ time.
- `isFull(rb: &RingBuffer) -> Bool`: Returns `true` if `count == capacity`.
- `isEmpty(rb: &RingBuffer) -> Bool`: Returns `true` if `count == 0`.
- `size(rb: &RingBuffer) -> Int`: Number of active items currently stored.
- `capacity(rb: &RingBuffer) -> Int`: Total capacity (always a power of two).
- `clear(rb: &RingBuffer) -> RingBuffer`: Resets buffer pointers and count to 0 in $O(1)$ or $O(C)$ time.
- `toArray(rb: &RingBuffer) -> Array[Int]`: Materializes the elements in FIFO order from head to tail into an array.

## Algorithm and boundaries

1. **Power-of-Two Capacity:**
   The user-requested `minCapacity` is rounded up via bit twiddling to the next power of 2 ($2^k \ge \text{minCapacity}$).
2. **Branchless Ring Indexing:**
   The slot mask is $\text{mask} = \text{capacity} - 1$. Any logical head or tail pointer maps to a physical array index in one CPU instruction:
   $$\text{physicalIndex} = \text{pointer} \mathbin{\&} \text{mask}$$
   This eliminates hardware integer division instructions and branch mispredictions.
3. **Flat Control Flow:**
   Push and pop operations avoid nested pattern matching, using atomic Option unwrapping and immutable record construction.

## Grill Log

- **Q:** Why force power-of-two capacities?
  **A:** Non-power-of-two circular buffers require `% capacity` (integer division, typically 15–40 CPU cycles) or conditional branches on index wrap. A bitwise mask `& (capacity - 1)` compiles to a single 1-cycle ALU `and` instruction.
- **Q:** Does `push` overwrite existing data when full?
  **A:** `push` is bounded and safe: it returns `None` on full capacity, preventing silent data loss.

## Referenced by

[[src/Std/_MOC]] · [[Std Buffer]] · [[architecture/STDLIB]]
