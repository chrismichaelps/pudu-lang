---
type: module
path: "@root/lib/Std/App/Jwt.pudu"
fidelity: Active
domain: "[[Standard Library]]"
subsystem: "[[architecture/STDLIB]]"
tags: [module, stdlib, authentication, security, jwt, rfc7519, hs256]
aliases: [Std App Jwt]
---

# Std App Jwt

## Purpose

RFC 7519 JSON Web Token (JWT) encoding, decoding, and cryptographic validation using HMAC-SHA256 (HS256) and constant-time signature verification.

## Interface

- `JwtClaims`:
  Structured token payload claims containing:
  - `subject: Option[Str]` (`sub` claim)
  - `issuer: Option[Str]` (`iss` claim)
  - `audience: Option[Str]` (`aud` claim)
  - `expiresAt: Option[Int]` (`exp` claim in epoch seconds)
  - `notBefore: Option[Int]` (`nbf` claim in epoch seconds)
  - `issuedAt: Option[Int]` (`iat` claim in epoch seconds)
  - `tokenId: Option[Str]` (`jti` claim)
  - `custom: Array[(Str, Str)]` (application-specific string key/value pairs)
- `JwtValidation`:
  Validation criteria:
  - `expectedIssuer: Option[Str]`
  - `expectedAudience: Option[Str]`
  - `leewaySeconds: Int` (clock skew tolerance)
- `JwtError`:
  Structured failure variants:
  - `MalformedToken`: Token does not have three dot-delimited Base64Url segments or Base64 decoding fails.
  - `InvalidSignature`: The computed HMAC-SHA256 signature does not match the token's signature under constant-time comparison.
  - `UnsupportedAlgorithm`: The token header does not declare `alg: "HS256"`.
  - `ExpiredToken`: The current time exceeds `exp + leewaySeconds`.
  - `TokenNotYetValid`: The current time with leeway is prior to `nbf`.
  - `IssuerMismatch`: The token issuer does not equal `expectedIssuer`.
  - `AudienceMismatch`: The token audience does not equal `expectedAudience`.
  - `InvalidClaimsJson`: The payload is not valid JSON or cannot be decoded.
- `claims() -> JwtClaims`:
  Initializes an empty claims object.
- `withSubject(c: &JwtClaims, sub: Str) -> JwtClaims`: Sets the `sub` claim.
- `withIssuer(c: &JwtClaims, iss: Str) -> JwtClaims`: Sets the `iss` claim.
- `withAudience(c: &JwtClaims, aud: Str) -> JwtClaims`: Sets the `aud` claim.
- `withExpiresAt(c: &JwtClaims, exp: Int) -> JwtClaims`: Sets the `exp` expiration timestamp in epoch seconds.
- `withNotBefore(c: &JwtClaims, nbf: Int) -> JwtClaims`: Sets the `nbf` activation timestamp in epoch seconds.
- `withIssuedAt(c: &JwtClaims, iat: Int) -> JwtClaims`: Sets the `iat` timestamp in epoch seconds.
- `withTokenId(c: &JwtClaims, jti: Str) -> JwtClaims`: Sets the `jti` unique token ID.
- `withClaim(c: &JwtClaims, key: Str, value: Str) -> JwtClaims`: Adds or updates a custom key/value claim.
- `getClaim(c: &JwtClaims, key: Str) -> Option[Str]`: Retrieves a claim value (checking standard and custom claims).
- `expiresIn(c: &JwtClaims, durationSeconds: Int, nowSeconds: Int) -> JwtClaims`: Configures expiration relative to a base timestamp.
- `hasExpired(c: &JwtClaims, nowSeconds: Int, leewaySeconds: Int) -> Bool`: Tests whether the token is past its expiration time including clock skew.
- `isValidAt(c: &JwtClaims, nowSeconds: Int, leewaySeconds: Int) -> Bool`: Validates that current time falls between not-before (`nbf`) and expiration (`exp`) with leeway.
- `validation() -> JwtValidation`:
  Constructs a validation policy with 0 seconds leeway and no mandatory issuer or audience.
- `requireIssuer(v: &JwtValidation, iss: Str) -> JwtValidation`: Enforces matching issuer.
- `requireAudience(v: &JwtValidation, aud: Str) -> JwtValidation`: Enforces matching audience.
- `withLeeway(v: &JwtValidation, seconds: Int) -> JwtValidation`: Sets clock skew tolerance in seconds.
- `encode(claims: &JwtClaims, secret: &Bytes) -> Str`:
  Serializes the standard HS256 header and claims payload into compact Base64Url JSON strings, signs them via HMAC-SHA256, and returns the canonical `header.payload.signature` token.
- `decode(token: Str, secret: &Bytes, rule: &JwtValidation, nowSeconds: Int) -> Result[JwtClaims, JwtError]`:
  Verifies the token's HMAC-SHA256 signature in constant time, parses the header and claims, and validates time boundaries (`exp`, `nbf`) and identity constraints (`iss`, `aud`).
- `decodeUnverified(token: Str) -> Result[JwtClaims, JwtError]`:
  Decodes claims without signature verification, enabling unverified inspection of token metadata (e.g. for key ID lookup or tenant routing).

## Governance and Algorithm

**Constant-time signature verification.** JWT signatures are validated against `hmacSha256Of` digests using `Crypto.secretsMatch` across the entire signature string. This prevents timing side-channels that would otherwise allow an attacker to reconstruct valid signatures byte-by-byte.

**Strict algorithm enforcement.** The decoder verifies that the decoded header contains `"alg": "HS256"`. Any `none` algorithm or mismatched algorithm is rejected immediately with `UnsupportedAlgorithm`, mitigating algorithm confusion vulnerabilities.

**Clock skew resilience.** Verification checks `exp` and `nbf` against `nowSeconds` modified by `leewaySeconds`, tolerating minor clock synchronization differences between distributed application nodes.

## Grill Log

- **Q:** Why support HS256 instead of asymmetric RS256/ES256 in the standard library core?
  **A:** HS256 relies on standard HMAC-SHA256, which executes efficiently at bare-metal speed using the native runtime's cryptographic primitives without introducing bulky RSA/ECC ASN.1 certificate and DER parsing dependencies into the core standard library.
- **Q:** How are custom claims handled in `JwtClaims`?
  **A:** Custom claims are stored as an associative array of key-value text pairs. They are serialized directly into the payload JSON object alongside registered RFC 7519 claims (`sub`, `iss`, etc.), and extracted during decoding.
- **Q:** What prevents replay attacks or expired token usage?
  **A:** Tokens specify `exp` and optional `jti`. Applications can inspect `claims.expiresAt` and track `claims.tokenId` in memory or Redis/database to implement revocation lists.

## Referenced by

[[src/Std/_MOC]] · [[Std App Session]] · [[Std App Totp]] · [[Std App Secret]] · [[architecture/WEB]]

## Boundary completion

Expiry is inclusive at exp. Registered claims with wrong kinds and duplicate payload names are refused instead of being interpreted as absent.
Resolved Grill Log: reject unsupported transport/representation behavior rather than emit corrupted output or silently weaken validation. No tests or reviews run.

## Strict compact-token boundaries

Decode rejects negative leeway, tokens above 65536 characters, noncanonical base64url segments,
duplicate JOSE header fields and unsupported critical/b64 header extensions. Reserved claims
cannot be injected through custom entries during encoding. This API supports HS256 and a
single string audience only; it is not a complete JOSE implementation. Readiness remains
unproven under the user's renewed code-only instruction.
