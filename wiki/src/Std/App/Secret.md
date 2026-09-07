---
type: module
path: "@root/lib/Std/App/Secret.pudu"
fidelity: Active
domain: "[[Pudu Program]]"
subsystem: "[[Standard Library]]"
grammar: "[[grammar/pudu]]"
tags: [module, stdlib, application, security, secrets, redaction]
aliases: [Std App Secret]
---

# Std App Secret

## Purpose and interface

A secret value that cannot be accidentally logged, serialized, or disclosed in error diagnostics. Enforces explicit redaction and provides constant-time equality comparisons to prevent side-channel timing attacks.

Exports:
- `type Secret = { raw: Str }`: An opaque container encapsulating a sensitive credential.
- `secret(value: Str) -> Secret`: Wraps a string as a protected secret.
- `reveal(s: &Secret) -> Str`: Explicitly unveils the sensitive string when passing to authenticated drivers or cryptographic functions.
- `redact(s: &Secret) -> Str`: Answers `"[REDACTED]"` for safe inclusion in logs, traces, and audit messages.
- `redactKey(s: &Secret, visibleSuffix: Int) -> Str`: Answers a partially masked string (e.g., `"••••••4f2a"`) for safe credential identification in audit logs.
- `constantTimeEquals(a: &Secret, b: &Secret) -> Bool`: Compares two secrets in constant time, preventing timing attacks on token verification.

## Complexity and limits

Wrapping and redaction execute in $O(1)$ time. `constantTimeEquals` executes in $O(N)$ time proportional to string length and does not short-circuit on mismatch.

## Grill Log

- **Q:** Why make `Secret` an explicit type instead of relying on conventions? **A:** String-based secrets invariably leak into log aggregators, exception messages, and traces. Making `Secret` a distinct nominal type requires explicit `reveal` calls to reach the payload, and guarantees that formatting functions default to `[REDACTED]`.
- **Q:** Does `redactKey` expose key length? **A:** No; `redactKey` produces a fixed mask prefix (`"••••••••"`) followed by at most `visibleSuffix` characters, preventing key length inference.

## Dependencies and consumers

- Consumed by application configuration ([`Std App Config`]), database credentials, HTTP server authentication, and security auditing.

## Referenced by

[[src/Std/_MOC]] · [[2026-09-06-application-stack]] · [[WEB]]
