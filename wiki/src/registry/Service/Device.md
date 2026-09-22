---
type: module
path: "@root/registry/src/Service/Device.pudu"
fidelity: Active
tags: [registry, login, device pairing]
aliases: [registry Service Device]
---
# Registry Service Device

`begin` stores a pairing under the digest of a 64-hex device code with an eight-character user code (`XXXX-XXXX`, no vowels or look-alike characters) valid for `LIFETIME_MILLIS`; `approve` marks it approved for a signed-in handle (case-insensitive code); `poll` answers `Waiting`, `Expired`, `Unknown`, or `Approved(handle, token)` once, issuing a `publish` token and deleting the pairing.

See [[architecture/PACKAGES]] · [[src/registry/_MOC]].

## Grill Log

- **Q:** Keep the device code in plain text? **A:** No, its digest names the record. _Rationale:_ the device code is a bearer credential until it is spent.

Resolved Grill Log: behaviour covered by `registry/src/Test/Registry.pudu`.
