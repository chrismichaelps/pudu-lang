---
type: module
path: "@root/packages/pudu/v0.1/lib/Std/Db/Challenge.pudu"
fidelity: Active
tags: [database, authentication]
aliases: [Std Db Challenge]
---
# Std Db Challenge

## Purpose and interface

Pure admission of the two Database authentication challenge phases. PAYLOAD_BYTES is 8192; MAX_ROUNDS is 1000000. First carries the exact text, extended nonce, decoded salt and admitted rounds. first(payload, clientNonce) returns First or a redacted textual refusal; signature(payload) returns exactly 32 bytes or a refusal. Session maps these refusals to its existing Auth case.

## Algorithm and resolved Grill Log

Check bytes before decoding; require phase 11 or 12 and valid text. Required first fields appear as r, s, i; final begins with v or a refused e. Attribute names are single letters, unique and carry a nonempty value without a zero byte. Refuse mandatory m; ignore well-formed optional extensions. The nonce strictly extends the client prefix and contains only printable characters excluding comma. Canonical salt encoding admits a nonempty salt. Positive decimal rounds have no sign, whitespace, leading zero or fallback; bounded accumulation refuses before arithmetic overflow. Canonical proof decoding requires 32 bytes.

- **Q:** Default malformed rounds? **A:** No; return a typed admission refusal through Session.
- **Q:** Derive before checking bounds? **A:** No; validate the complete first phase first.
- **Q:** Flatten optional extensions? **A:** No; retain exact original text for proof binding.
- **Q:** Claim a computation deadline? **A:** No; the work ceiling is finite, not preemption.

## Work evidence

Three local optimized derivation samples per count use a 32-byte key, password pencil and salt salt, with elapsedMilliseconds surrounding deriveKey and the length check. Medians are 3 ms for 4096 rounds, 641 ms for 1000000 and 6257 ms for 10000000. Admission limits server-selected rounds tenfold; a larger count performs no derivation. This is finite work evidence, not a portable response deadline.

## Referenced by

[[Std Db Session]] · [[Database Challenge Fixture]] · [[src/Std/_MOC]]
