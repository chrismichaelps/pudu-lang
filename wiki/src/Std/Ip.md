---
type: module
path: "@root/lib/Std/Ip.pudu"
fidelity: Active
domain: "[[Pudu Program]]"
subsystem: "[[Standard Library]]"
grammar: "[[grammar/pudu]]"
tags: [module, stdlib, network, security]
aliases: [Std Ip]
---

# Std Ip

## Purpose and interface

Internet addresses and network prefixes as values, so an allowlist, a trusted-proxy rule, or a
per-subnet limit compares numbers rather than text.

- `type Family = V4 | V6`; `type Address = { family, bits: UInt128 }`; `type Network = { base, prefix }`.
- `type IpError = Empty | BadOctet(Str) | LeadingZero(Str) | WrongPartCount(Int) | BadGroup(Str) |
  MisplacedCompression | BadPrefix(Str) | HostBitsSet | WrongLength(Int)`; `explain(problem) -> Str`.
- `parse(text) -> Result[Address, IpError]`, `render(address) -> Str`, `v4(a, b, c, d)`,
  `isV4`, `isV6`, `width`.
- `toBytes(address) -> Bytes`, `fromBytes(bytes) -> Result[Address, IpError]` (4 or 16 bytes,
  network order).
- `unmap(address)`, `mapToV6(address)`, `next`, `previous` (`Option`, bounded by the family),
  `compare -> Int` (IPv4 before IPv6, then numerically).
- `isLoopback`, `isPrivate`, `isLinkLocal`, `isMulticast`, `isUnspecified`, `isDocumentation`,
  `isShared`, `isPublic`.
- `parseNetwork(text) -> Result[Network, IpError]`, `renderNetwork`, `networkOf(address, prefix)
  -> Option[Network]`, `contains`, `overlaps`, `first`, `last`, `netmask`, `hostBits`,
  `within(networks, address) -> Bool`.

## Semantics

- Both families live in one `UInt128`; an IPv4 address uses the low 32 bits. The family is part of
  equality, so `0.0.0.1` and `::1` differ.
- A dotted quad is exactly four decimal parts of at most three digits, each 0–255, with no leading
  zero. IPv6 is eight 1–4 digit hex groups, or fewer around exactly one `::` that stands for at least
  one group; only the final group may be a dotted quad. Zone suffixes are refused.
- `render` is RFC 5952: lowercase, no leading zeros in a group, the longest run of two or more zero
  groups (the first on a tie) written `::`; an IPv4-mapped address keeps its dotted tail. `parse`
  reads every rendering back to the same address.
- `parseNetwork` refuses host bits past the prefix (`HostBitsSet`) and prefixes written with a
  leading zero, empty, or wider than the family; `networkOf` clears host bits for a caller that
  means to. A bare address is its own full-width network.
- `contains` never matches across families. `within` unmaps its address first; `isPublic` judges a
  mapped address by the IPv4 address it carries and, for IPv6, requires `2000::/3`.
- Shifts never reach the full 128-bit width: `::` fills its groups one 16-bit shift at a time,
  because a shift by the whole width is refused at run time.

## Grill Log

- **Q:** Clear host bits in `parseNetwork` like most readers do? **A:** No. _Rationale:_
  `10.1.2.3/8` is usually a typo for a narrower rule, and silently widening it grants far more than
  meant. _Rejected:_ implicit masking; `networkOf` is the explicit path.
- **Q:** Accept leading zeros in a dotted quad? **A:** No. _Rationale:_ some readers take them as
  octal, so one rule would mean two addresses. _Rejected:_ decimal-with-zeros leniency.
- **Q:** Make `contains` unmap automatically? **A:** No; `within` does. _Rationale:_ `contains` is a
  precise set question and stays total over its two arguments, while the allowlist question is the
  one where forgetting to unmap opens a hole. _Rejected:_ family-agnostic comparison everywhere.
- **Q:** Separate IPv4 and IPv6 types? **A:** One type with a family. _Rationale:_ an allowlist holds
  both, and every operation is written once over 128 bits.

## Dependencies and consumers

- Depends on the prelude only (`convertInteger`, `bytesOf`, `display`).
- Reached by [[Uses Ip All]]; intended for server trust rules, rate limiting, and audit logs.

## Referenced by

[[src/Std/_MOC]] · [[architecture/STDLIB]] · [[Uses Ip All]]
