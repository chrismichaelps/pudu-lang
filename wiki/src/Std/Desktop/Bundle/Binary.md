---
type: module
path: "@root/lib/Std/Desktop/Bundle/Binary.pudu"
fidelity: Active
domain: "[[Pudu Program]]"
subsystem: "[[Standard Library]]"
grammar: "[[grammar/pudu]]"
tags: [module, stdlib, desktop, packaging]
aliases: [Std Desktop Bundle Binary]
---

# Std Desktop Bundle Binary

## Purpose and interface

Byte layouts the package writers share: `u16`, `u32` and `u64` write big-endian integers from `Int`;
`padded` and `alignTo` pad with zeros; `ar` writes a Unix `ar` archive; `cpio` writes a `newc` cpio
archive from `CpioEntry` values; `octal` and `hex8` write fixed-width numbers.

## Semantics

- An integer outside the width's range is written as zero bits above the width: callers check sizes
  against format limits before writing (an `ar` member is limited to ten decimal digits, a `cpio`
  field to eight hexadecimal digits).
- `ar` writes the global header, then for each member a 60-byte header (name, a zero timestamp,
  owner and group 0, mode `100644`, size) and its data, padded to an even length.
- `cpio` writes each entry with a `070701` header, its name and a terminating NUL padded to four
  bytes, its data padded to four bytes, and ends with `TRAILER!!!`; inode numbers count from one.

## Grill Log

- **Q:** Why zero timestamps in `ar`? **A:** The same inputs then produce the same package bytes,
  which makes packages comparable and patches small.

## Dependencies and consumers

Uses [[Std Bytes]]. Consumed by [[Std Desktop Bundle Deb]] and [[Std Desktop Bundle Rpm]].

## Referenced by

[[src/Std/_MOC]]
