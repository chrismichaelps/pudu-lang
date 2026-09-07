---
type: module
path: "@root/lib/Std/App/Tenant.pudu"
fidelity: Active
domain: "[[Standard Library]]"
subsystem: "[[architecture/STDLIB]]"
tags: [module, stdlib, multitenancy, quota, admission]
aliases: [Std App Tenant]
---

# Std App Tenant

## Purpose

Multi-tenant isolation, noisy-neighbor mitigation, per-tenant resource bounding, and quota admission control.

## Interface

- `Tier`:
  `Free | Standard | Enterprise`
- `Quota`:
  `{ maxInflight: Int, maxRequestsPerMinute: Int, maxPayloadBytes: Int }`
- `Tenant`:
  `{ id: Str, name: Str, tier: Tier, quota: Quota, active: Bool }`
- `TenantState`:
  Mutable runtime metrics tracking `inflight` concurrent requests, `windowStart` epoch seconds, and `requestCount`.
- `TenantRegistry`:
  Thread-safe synchronized store coordinating tenant definitions and per-tenant dynamic admission states.
- `registry() -> TenantRegistry`:
  Initializes a fresh empty tenant registry.
- `register(reg: &TenantRegistry, tenant: Tenant) -> ()`:
  Inserts or updates a tenant definition and initializes its admission state.
- `get(reg: &TenantRegistry, tenantId: Str) -> Option[Tenant]`:
  Looks up a registered tenant by ID.
- `setQuota(reg: &TenantRegistry, tenantId: Str, quota: Quota) -> Bool`:
  Dynamically adjusts resource quotas for an existing tenant.
- `setActive(reg: &TenantRegistry, tenantId: Str, active: Bool) -> Bool`:
  Enables or suspends a tenant account.
- `admit(reg: &TenantRegistry, tenantId: Str, payloadLength: Int) -> Admission`:
  Atomically evaluates admission criteria: tenant registration, active status, payload size, per-minute request rate, and concurrent in-flight limit. If all criteria pass, increments in-flight and rate counters and admits the request.
- `release(reg: &TenantRegistry, tenantId: Str) -> ()`:
  Atomically decrements the active in-flight request counter for the tenant upon completion.
- `scopedKey(tenantId: Str, resourceKey: Str) -> Str`:
  Constructs a canonical isolated resource identifier (`"tenant:{tenantId}:{resourceKey}"`) preventing cross-tenant data collisions in shared caches and key-value stores.
- `resolveFromHeader(headerName: Str) -> fn(&Route.Request) -> Option[Str]`:
  Resolves tenant ID from an HTTP request header (e.g. `X-Tenant-Id`).
- `resolveFromSubdomain(domainSuffix: Str) -> fn(&Route.Request) -> Option[Str]`:
  Extracts tenant ID from the host header subdomain prefix.
- `guard(reg: &TenantRegistry, resolve: fn(&Route.Request) -> Option[Str]) -> Route.Middleware`:
  HTTP middleware enforcing tenant resolution, admission backpressure, rate limits, payload size bounds, and account suspension.

## Governance and Algorithm

**Noisy neighbors cannot exhaust shared resources.** In multi-tenant systems, a sudden traffic spike or runaway loop from a single tenant must never degrade service for other tenants on the same cluster. `Std.App.Tenant` isolates concurrency and throughput per tenant. When a tenant reaches their `maxInflight` allocation, further requests from that tenant are fast-shed with HTTP 503 and `Retry-After: 1`, leaving worker capacity intact for adjacent tenants.

**Suspension is instantaneous.** When an account is suspended (`active: false`), all subsequent requests from that tenant are refused immediately with HTTP 403 Forbidden without reaching backend handlers or database connections.

**Data isolation is explicit.** `scopedKey` enforces prefix separation across shared storage media, preventing one tenant from referencing another tenant's cached pages or database entities.

## Grill Log

- **Q:** Why enforce concurrency limits per tenant in addition to global server backpressure?
  **A:** Global backpressure protects the server from dying, but a single rogue tenant generating thousands of requests would starve all other tenants. Per-tenant concurrency limits guarantee that every tenant receives a fair share of the server's worker pool.
- **Q:** How are moving windows calculated for tenant rate limiting?
  **A:** Each tenant tracks their own 60-second window in memory. When the clock advances past the window start, the request count resets.
- **Q:** What if a request does not specify a tenant?
  **A:** `guard` returns HTTP 401 Unauthorized (`"missing or invalid tenant identifier"`), preventing unauthenticated or unscoped access to multi-tenant routes.

## Referenced by

[[src/Std/_MOC]] · [[Std App Access]] · [[Std Http Server Guard]] · [[architecture/WEB]] · [[ADR-0017 What the Web Layer Refuses]]
