---
type: module
path: "@root/packages/pudu/v0.1/src/Pudu/Backend/Runtime/Host/TlsTrust.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
aliases: [Native Mobile TLS Trust]
---
# Native Mobile TLS Trust

Emit the peer verification callbacks selected by [[Native Host TLS]].
OpenSSL keeps the handshake and socket. The callback checks the configured
DNS name or IP against the leaf and asks the mobile platform to validate
the certificate chain. Its result becomes OpenSSL's verification result.

## Resolved Grill Log

- iOS creates a Security trust object from the received chain and checks the
  server policy with network fetching disabled.
- Android obtains a thread-local JNI environment from the host's JavaVM,
  decodes the chain into X.509 certificates, and calls the platform trust
  manager with the peer name and authentication type. A host registers the
  VM before entering Pudu. A missing VM fails verification.
- Only the call that attaches a native thread detaches it. Certificate
  buffers, JNI references and Core Foundation objects remain scoped to one
  verification. A JNI exception from the trust path is a failed handshake.
- No generated program can change the platform trust callback or configure
  verification to accept an untrusted chain.

## Referenced by

[[Native Host TLS]] · [[Backend Toolchain Library]] · [[src/Pudu/Backend/_MOC]]
