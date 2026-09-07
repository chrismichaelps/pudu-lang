---
type: module
path: "@root/lib/Std/App/Audit.pudu"
fidelity: Active
domain: "[[Standard Library]]"
subsystem: "[[architecture/STDLIB]]"
tags: [module, stdlib, audit, security, compliance]
aliases: [Std App Audit]
---

# Std App Audit

## Purpose

Structured, append-only, tamper-evident security audit logging for compliance, forensics, and intrusion detection.

## Interface

- `Outcome`:
  `Success | Failure(Str) | Denied(Str)`
- `AuditEvent`:
  Immutable security event record holding `id`, `timestamp`, `action`, `principal`, `resource`, `outcome`, `clientIp`, `details`, `prevHash`, and `hash`.
- `AuditLog`:
  Thread-safe append-only ledger protected by synchronization primitives and maintaining an unbroken cryptographic SHA-256 hash chain.
- `auditLog() -> AuditLog`:
  Initializes a fresh audit ledger seeded with the standardized 64-hex-zero genesis hash.
- `record(log: &AuditLog, action: Str, principal: Str, resource: Str, outcome: Outcome, clientIp: Str, details: Map[Str, Str]) -> AuditEvent`:
  Constructs a new audit event, automatically redacting known credential fields (`password`, `token`, `secret`, `authorization`, `cookie`, `key`, `cvv`), binds the current `headHash` as `prevHash`, calculates the SHA-256 digest over the canonical payload, atomically advances the ledger head, and appends the entry.
- `verifyIntegrity(log: &AuditLog) -> Bool`:
  Traverses the ledger from genesis to head, recalculating each event's cryptographic digest and verifying strict hash chaining. Returns `false` if any record was modified, dropped, or reordered.
- `renderJson(event: &AuditEvent) -> Str`:
  Emits an RFC 8259 compliant structured single-line JSON string suitable for SIEM forwarders (Datadog, Splunk, Elastic).
- `renderNdjson(log: &AuditLog) -> Str`:
  Serializes the entire ledger into newline-delimited JSON (NDJSON) format for audit dumps.
- `redactSensitive(key: Str, value: Str) -> Str`:
  Masks values associated with sensitive credential keys with `"[REDACTED]"`.

## Governance and Algorithm

**Tamper evidence is built into the data structure.** Traditional audit logs written as unstructured text files can be secretly edited or truncated by an attacker with filesystem access. In `Std.App.Audit`, each event cryptographically commits to the SHA-256 digest of the immediately preceding event (`prevHash`). If a past entry is altered, deleted, or inserted, the entire downstream hash chain breaks, and `verifyIntegrity` immediately detects the tampering.

**Sensitive credentials never enter the audit stream.** Logging an authentication failure must record who tried to authenticate and from where, but must never record the submitted password or authorization token. `record` enforces redaction across all detail fields by default, replacing sensitive values with `"[REDACTED]"` before hashing or serialization.

**Structured representation is mandatory.** Unstructured free-form log text requires fragile regex parsing by downstream SIEM tools. `Std.App.Audit` produces canonical structured records and newline-delimited JSON output with explicit timestamps and typed outcomes.

## Grill Log

- **Q:** Why use an in-memory hash chain rather than writing directly to a database or syslog?
  **A:** Audit logging must remain decoupled from specific storage backends. An application can hold the audit log in memory, ship it over HTTP, stream it to disk, or flush it to PostgreSQL. Providing a cryptographically chained value type guarantees integrity regardless of the transport medium.
- **Q:** Does SHA-256 hashing impose high computational overhead?
  **A:** No. Hashing a canonical string of fewer than 512 bytes takes less than 1 microsecond using hardware-accelerated SHA-256 builtins (`sha256Of`).
- **Q:** Can an attacker forge a hash chain if they have code execution?
  **A:** If an attacker can overwrite in-memory state, local detection is bounded by process isolation. However, once audit events are streamed or replicated to an external collector (e.g. SIEM or object storage), the attacker cannot alter past records without breaking the cryptographic chain held by the remote observer.
- **Q:** Why include `Outcome.Denied` separately from `Outcome.Failure`?
  **A:** Security analysis treats authorization rejections (403/permission denied) differently from system failures (500/internal error). Distinguishing `Denied` from `Failure` allows direct detection of brute-force and privilege escalation attempts.

## Referenced by

[[src/Std/_MOC]] · [[Std App Secret]] · [[Std Http Server Guard]] · [[architecture/WEB]] · [[ADR-0017 What the Web Layer Refuses]]
