---
type: module
path: "@root/test-fixtures/stdlib/UsesMobileResource.pudu"
fidelity: Active
tags: [module, fixture, stdlib, mobile, native, network]
aliases: [Uses Mobile Resource]
---

# Uses Mobile Resource

## Purpose and interface

Stdlib fixture for [[Std Mobile Resource]]. Its entry `main` drives `table`, `reconcile`, `received`, `status`, `size` and `trimmed` through the checks below and answers the number of checks that held. The data spec `test/Pudu/Compiler/Program/Eval/DataSpec.hs` asserts that count, which is 12.

Checks:
1. A new key starts one request under generation 1 and its status is `Pending`; describing it again while in flight sends nothing, including when it is described twice in one call.
2. A 200 settles the key as `Loaded`; it sends nothing while fresh and one request after `freshFor`.
3. A response for a generation no longer in flight changes nothing.
4. A key nothing describes has its request cancelled.
5. A changed request cancels the old generation and starts the new request as generation 2.
6. A 503 is `Pending`; the reconcile at its retry time emits one wake between 100 and 600 ms, and the retry starts at 700 ms.
7. Retry-After of 5000 ms gives a wake at 5100 ms, and the request starts exactly then, not earlier.
8. Failures show only after the policy's retries: the second 503 is `Pending`, the third is `Failed(503, ...)`, and a loaded result stays `Loaded` while a refresh fails.
9. A 404 settles at once as `Failed(404, ...)` and sends nothing while fresh.
10. An undescribed entry is kept for `keptFor` as one entry holding its loaded status, and dropped after that.
11. Under a capacity of one, only one undescribed entry is kept, and `trimmed` removes it.

## Invariants

- Each check compares an exact command list, status or size, never a length alone, except where the wake is the only command.
- The fixture makes no foreign call and no host is started. It runs interpreted and as native C11, and both must agree.

## Negative Logic

- No network and no host. The host's execution of commands is checked by the simulator run of [[Native Remote Example]].
- No check of the body spelling in the stream. [[Uses Mobile View]] and [[Std Mobile Stream]] own the bytes.

## Dependencies and consumers

Depends on [[Std Mobile Resource]], and on `Std.Mobile.View` for the `Fetched` and `MemoryLow` events it constructs through `observe`. Its checks mirror the rules in [[Std Mobile Resource]].

## Resolved Grill Log

- **Q:** Check commands or summaries? **A:** Exact commands and statuses. A check of "a request was sent" would pass a wrong generation or URL.
- **Q:** Why a retry check that accepts a range? **A:** Full jitter draws the delay, so only its bounds are fixed; the Retry-After check fixes the exact instant.

## Referenced by

[[src/_MOC]] · [[Std Mobile Resource]] · [[Uses Mobile View]] · [[Native Remote Example]]
