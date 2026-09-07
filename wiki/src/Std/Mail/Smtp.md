---
type: module
path: "@root/lib/Std/Mail/Smtp.pudu"
fidelity: Active
tags: [module, stdlib, mail, smtp, tls]
aliases: [Std Mail Smtp]
---
# Std Mail Smtp

## Purpose and interface

Deliver Std.Mail.Message values through SMTP with verified implicit TLS or required STARTTLS.
`client(host,port,domain)` selects ImplicitTls on port 465 and StartTlsRequired otherwise. Configuration
contains host, port, domain, credentials, timeoutMs and security. EHLO domain is a required application setting; it is never inferred from the remote server or defaulted to localhost. `withSecurity` explicitly selects
Plaintext, ImplicitTls or StartTlsRequired. `withDomain`, `withTimeout`, `withAuth` (LOGIN) and
`withPlainAuth` (PLAIN) return updated configurations. Direct SmtpClient literals must include security.

`deliver` returns Result[Int,SmtpError], the count accepted after DATA succeeds. `parseReply` and
command-formatting helpers remain available. Errors distinguish connection, greeting, authentication,
recipient, DATA, command and timeout failures. No automatic retries occur: a lost acknowledgement after
DATA can mean delivery succeeded, so retry decisions belong to an application’s deduplication policy.

## Transport and protocol

Implicit TLS verifies the named host before reading a greeting. Required STARTTLS reads greeting and
EHLO, requires STARTTLS advertisement and a 220 upgrade reply, consumes the plain connection token,
verifies TLS and sends a fresh EHLO. Capabilities observed before encryption are discarded. Failure
never falls back to plaintext. System trust and TLS 1.2/1.3 are supplied by [[Eval Tls]]. Applications
must not concurrently use a plain connection while upgrading it.

AUTH is permitted only through a secure configuration and only when its mechanism appears in the
post-TLS EHLO capabilities. LOGIN and PLAIN use base64 payloads; embedded NUL and credentials exceeding
the supported line budget are refused. Plaintext mode is an explicit local relay option and refuses
all credentials. No certificate-verification bypass is exposed.

Replies accumulate as bytes before UTF-8 decoding and must have complete CRLF lines, three ASCII
status digits, consistent multiline codes, hyphen continuations and one final line. Each line is
limited to 512 octets including CRLF and each reply to 65536 bytes. Each reply has one monotonic read
budget. Timeout configuration is 1..86400000 ms. These are operation/reply budgets, not a whole-mail
transaction deadline. EHLO domain and Mail.sendable are checked before connecting.

MAIL FROM, RCPT TO and DATA use Mail’s separate envelope and dot-stuffed rendering. Blind recipients
remain absent from message headers. Rejected recipients stop before DATA. Ordinary result paths close
the current transport; an upgraded token replaces the retired plain token. QUIT is best effort after
accepted DATA. SMTPUTF8, MIME transfer encoding, OAuth SASL and delivery queues are separate work.

## Usage

```pudu
let submission = Smtp.withAuth(&Smtp.client(smtpHost, smtpPort, ehloDomain), user, password)
let accepted = Smtp.deliver(&submission, &message) ?
```

Supply `smtpHost`, `smtpPort` and `ehloDomain` from application configuration. The EHLO identity is
the client's fully qualified name or address literal, distinct from the server destination. Host
must be nonempty and port must be in 1..65535. `withSecurity` overrides port-based transport defaults.



## Grill Log

- Resolved: fail closed when STARTTLS is absent or refused; never downgrade.
- Resolved: refresh EHLO after TLS and select AUTH only from encrypted capabilities.
- Resolved: retire the plain token once, transfer cleanup responsibility and close failed upgrades.
- Resolved: retain bounded byte parsing rather than treating TCP or TLS records as reply boundaries.
- Resolved: expose uncertain delivery to callers rather than retrying messages silently.

No builds, tests, reviews, measurements or live SMTP deliveries ran; readiness remains unproven.

## Referenced by

[[src/Std/_MOC]] · [[Std Mail]] · [[Std Net]] · [[Std Tls]] · [[architecture/WEB]]

Resolved Grill Log: require the EHLO identity at construction; do not silently guess a deployment hostname. The constructor now takes three arguments.

Existing constructor migration: [[src/test-fixtures/stdlib/UsesSmtp]].
