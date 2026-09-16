---
type: module
path: "@root/lib/Std/Http/Server/Security.pudu"
fidelity: Active
domain: "[[Pudu Program]]"
subsystem: "[[Standard Library]]"
grammar: "[[grammar/pudu]]"
tags: [module, stdlib, http, security, csp, csrf, headers, hsts]
aliases: [Std Http Server Security]
---

# Std Http Server Security

## Purpose and interface

Cyber attack mitigation and automated HTTP security hardening. Generates strict security headers, cryptographic nonces for Content Security Policy (CSP), Origin/Referer verification, and constant-time CSRF token comparisons.

Exports:
- `generateNonce(seed: Int) -> Str`: Generates a hexadecimal nonce string for per-request CSP inline script/style authorization.
- `strictSecurityHeaders(nonce: Str) -> Array[(Str, Str)]`: Emits standard defense-in-depth headers:
  - `Content-Security-Policy: default-src 'self'; script-src 'self' 'nonce-...'; style-src 'self' 'nonce-...'; object-src 'none'; base-uri 'self'; form-action 'self'`
  - `Strict-Transport-Security: max-age=63072000; includeSubDomains; preload`
  - `X-Content-Type-Options: nosniff`
  - `X-Frame-Options: DENY`
  - `Referrer-Policy: strict-origin-when-cross-origin`
  - `Permissions-Policy: camera=(), microphone=(), geolocation=()`
- `verifyOrigin(origin: Option[Str], referer: Option[Str], expectedHost: Str) -> Bool`: Validates that mutation requests (POST/PUT/DELETE) originate from the trusted host.
- `constantTimeCompare(a: &Str, b: &Str) -> Bool`: Compares authentication and CSRF tokens in constant time ($O(N)$ regardless of matching prefix) to mitigate timing attacks.

## Complexity and limits

Header construction is $O(1)$. Origin validation parses host components in $O(L)$. Constant-time comparison iterates through the entire length of the tokens, preventing side-channel leakage.

## Grill Log

- **Q:** Why use CSP nonces instead of `'unsafe-inline'`? **A:** Inline script execution is the primary vector for Cross-Site Scripting (XSS). Per-request nonces ensure only server-emitted scripts execute.
- **Q:** Why verify Origin before CSRF token? **A:** Validating Origin/Referer blocks cross-site requests at the outermost perimeter before decrypting or reading request body payloads.
- **Q:** How are timing attacks prevented on tokens? **A:** `constantTimeCompare` walks all characters using bitwise OR accumulation rather than exiting on the first mismatch.

## Dependencies and consumers

- [[Std Bits]] supplies bitwise operations for constant-time comparisons.
- [[Std Http Message]] supplies header records.
- Consumed by enterprise middleware and secure form handlers.

## Referenced by

[[src/Std/_MOC]] · [[2026-09-06-application-stack]]
