---
type: architecture
tags: [application, deployment, security]
aliases: [Application Deployment Contract]
---
# Application Deployment Contract

## Boundaries

Application code composes Route handlers, explicit resources and configuration. A deployment
adapter owns process startup, sockets or platform request conversion, cancellation and shutdown.
Database drivers own connections and transactions. Mail delivery adapters own provider or SMTP
transport; Std.Mail owns validated message serialization. No provider name belongs in a domain
handler. LSP capabilities remain independent of these boundaries.

## Implemented process deployment

App.run starts a TCP service with explicit host/port, request byte limits and middleware. It
validates numeric settings before opening resources. Config discovery layers declared defaults,
configuration files, environment and command arguments. Declare new keys before environment
overrides so applications can customize server.headBytes and server.bodyBytes. Total accepted
connections is not a concurrent-request quota. No horizontal autoscaling or distributed rate
limiting is implied by these settings.

A compatible host must provide the compiler/runtime dependencies, network access and any chosen
native database libraries. Local SQLite persistence requires suitable persistent storage; multiple
instances do not automatically share it. PostgreSQL resources require explicit connection limits
per instance. Application secrets must come from deployment configuration, never page data.

## Platform adapters still required

Named hosting providers are not interchangeable execution environments. A long-running process
deployment and a request-invoked function require different adapters. No Vercel, AWS function,
edge-runtime or universal binary compatibility is claimed. A function adapter must map method,
path, headers and body bytes without loss, apply bounded input admission, execute the same handler
chain and map responses back. Warm-instance resource reuse must be explicit and independent of
request-local authentication state. Shipping such adapters requires provider-specific packaging
and execution evidence; it is outstanding work.

## Security and scaling obligations

Keep security middleware on refusal responses. Configure explicit origins, deployment TLS and
trusted proxy boundaries; forwarded headers are not authentication. Never cache personalized
SSR globally without an application-defined identity and authorization partition. Output budgets
limit accepted bytes, not peak render allocation. Request deadlines, bounded concurrency, graceful
in-flight draining, distributed admission, authentication/CSRF coverage and provider packaging
remain requirements to address with concrete code and evidence. Avoid calling this framework
enterprise-ready until those obligations are demonstrated.

For mail, use renderChecked at an SMTP serialization boundary. Public message/address records
can bypass constructors, so sendable validates every envelope address again. Bcc stays outside
headers. Legacy render is unchecked; provider APIs need their own unstuffed payload mapping.
MIME encoding and SMTP capability negotiation remain separate transport responsibilities.

## Grill Log

- **Q:** Promise any-platform deployment through configuration alone? **A:** No; adapters and
  supported runtime packaging are required in addition to configuration.
- **Q:** Treat process-local controls as distributed protection? **A:** No; distinguish their
  scope and preserve explicit external coordination boundaries.
- **Q:** Silently fall back after invalid resource-limit input? **A:** No; fail before startup.

## Referenced by
[[architecture/_MOC]] · [[Std App]] · [[Std Mail]] · [[2026-09-06-application-stack]]
