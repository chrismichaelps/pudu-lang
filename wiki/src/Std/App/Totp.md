---
type: module
path: "@root/lib/Std/App/Totp.pudu"
fidelity: Active
domain: "[[Standard Library]]"
subsystem: "[[architecture/STDLIB]]"
tags: [module, stdlib, authentication, mfa, totp, rfc6238]
aliases: [Std App Totp]
---

# Std App Totp

## Purpose

Multi-factor authentication (MFA) implementing RFC 6238 Time-Based One-Time Passwords (TOTP) and RFC 4226 HMAC-Based One-Time Passwords (HOTP).

## Interface

- `TotpConfig`:
  Immutable parameters holding `secret: Bytes`, `digits: Int` (default 6), `stepSeconds: Int` (default 30), `skewSteps: Int` (default 1), `issuer: Str`, and `account: Str`.
- `TotpState`:
  Stateful replay prevention tracking `lastUsedStep: Sync.Cell[Int]` across validation attempts.
- `config(secret: Bytes, issuer: Str, account: Str) -> TotpConfig`:
  Initializes standard configuration with 6-digit output, 30-second time interval, and $\pm 1$ step clock skew tolerance.
- `trait Configuring`, implemented for `TotpConfig`:
  The three numbers a code's shape is decided by, as methods so a configuration reads as one chain in
  the order an authenticator app lists them.
  - `digits(count: Int) -> Self`: output code length (typically 6 or 8). A count of nothing or fewer
    is the default rather than a code with no digits, which would be the same code for everybody.
  - `step(seconds: Int) -> Self`: interval duration (RFC default: 30 seconds). An interval of nothing
    would make the step a division by zero, so it is the default instead.
  - `skew(steps: Int) -> Self`: clock skew allowance (default: 1 step, covering $\pm 30$ seconds of
    drift), counted in steps so it means the same thing whatever the interval is. Every step of
    allowance is another accepted code, so it is a window an attacker gets as well as a clock a user
    gets wrong. A negative allowance is none.
- `state() -> TotpState`:
  Constructs replay prevention tracking state.
- `generate(cfg: &TotpConfig, timestampSeconds: Int) -> Str`:
  Computes the canonical time-based OTP code for the given epoch timestamp using HMAC-SHA256 and dynamic truncation, padded with leading zeros.
- `verify(cfg: &TotpConfig, heldState: &TotpState, code: Str, timestampSeconds: Int) -> Bool`:
  Validates a user-submitted code against all allowed steps in $[C - \text{skew}, C + \text{skew}]$ using constant-time string comparison. Atomically guards against replay attacks: a code corresponding to an already consumed time step is rejected.
- `provisioningUri(cfg: &TotpConfig) -> Str`:
  Builds the standard `otpauth://totp/{issuer}:{account}?secret={base32}&issuer={issuer}&algorithm=SHA256&digits={digits}&period={period}` URI for authenticator app enrollment (Google Authenticator, 1Password, Authy).
- `encodeBase32(source: &Bytes) -> Str`:
  RFC 4648 Base32 encoder converting binary secrets into standard uppercase 32-character alphabet strings without padding.
- `decodeBase32(text: Str) -> Result[Bytes, Str]`:
  RFC 4648 Base32 decoder with whitespace stripping and case normalization.

## Governance and Algorithm

**Dynamic truncation complies strictly with RFC 4226.** The counter $C = \lfloor T / T_0 \rfloor$ is encoded into an 8-byte big-endian buffer and signed via `hmacSha256Of`. The low 4 bits of the final digest byte select the offset index $i \in [0, 15]$. A 31-bit unsigned integer is extracted from bytes $i \dots i+3$, masked with $0x7FFFFFFF$, and reduced modulo $10^{\text{digits}}$.

**Constant-time comparison prevents timing side-channels.** Comparing OTP strings via ordinary character-by-character equality leaks the count of matching leading digits through response latency. Verification in `Std.App.Totp` uses constant-time byte comparisons across the entire code length.

**Replay prevention is mandatory.** A valid OTP must not be accepted twice within the same time window. `verify` records the highest authenticated time counter step in `lastUsedStep`. Any subsequent request attempting to verify with a counter $\le \text{lastUsedStep}$ is rejected immediately.

## Grill Log

- **Q:** Why use HMAC-SHA256 instead of HMAC-SHA1?
  **A:** RFC 6238 permits SHA-256 and SHA-512 in addition to legacy SHA-1. Modern authenticator apps (YubiKey, 1Password, Bitwarden, modern Google Authenticator) support SHA-256, which provides superior cryptographic collision resistance.
- **Q:** Why provide Base32 codecs directly in this module?
  **A:** Authenticator applications exchange secrets exclusively via Base32 representations. Packaging the codec within `Std.App.Totp` ensures end-to-end QR code generation and secret exchange without external dependencies.
- **Q:** What happens if a client's clock is slightly out of sync?
  **A:** The configurable `skewSteps` parameter (defaulting to 1) checks $T-1$, $T$, and $T+1$, accommodating transmission latency and local device clock drift up to 30 seconds in either direction.

## Referenced by

[[src/Std/_MOC]] · [[Std App Password]] · [[Std App Session]] · [[Std App Secret]] · [[architecture/WEB]] · [[ADR-0017 What the Web Layer Refuses]]
