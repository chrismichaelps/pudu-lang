---
type: module
path: "@root/lib/Std/Mail/Smtp.pudu"
fidelity: Active
domain: "[[Standard Library]]"
subsystem: "[[architecture/STDLIB]]"
tags: [module, stdlib, mail, smtp, rfc5321, network, tls]
aliases: [Std Mail Smtp]
---

# Std Mail Smtp

## Purpose

RFC 5321 Simple Mail Transfer Protocol (SMTP) client transport delivering structured `Std.Mail.Message` values over raw streaming TCP (`Std.Net`) and TLS (`Std.Tls`).

## Interface

- `SmtpClient`:
  Immutable client configuration holding:
  - `host: Str`: Hostname or IP of the SMTP server.
  - `port: Int`: Port number (default 587 for STARTTLS submission, 465 for implicit TLS, 25 for plain relay).
  - `domain: Str`: Client identification domain sent in `EHLO` (default `"localhost"`).
  - `credentials: Option[SmtpAuth]`: Optional username/password authentication credentials.
  - `timeoutMs: Int`: Socket deadline in milliseconds for every operation (default 10,000 ms).
- `SmtpAuth`:
  Authentication credential variants:
  - `Login(Str, Str)`: RFC 4954 `AUTH LOGIN` with Base64 username and password challenges.
  - `Plain(Str, Str)`: RFC 4616 `AUTH PLAIN` single-message identity transmission.
- `SmtpReply`:
  Parsed server response status:
  - `code: Int`: Three-digit numeric reply code (e.g. 220, 250, 354, 550).
  - `lines: Array[Str]`: Server response text lines with hyphen/space continuation markers stripped.
- `SmtpError`:
  Structured SMTP transport failures:
  - `ConnectionFailed(Str)`: Network socket connection refused, unresolved, or dropped.
  - `HandshakeFailed(Int, Str)`: Server greeting rejected or invalid status code returned.
  - `AuthFailed(Int, Str)`: Server rejected client credentials during `AUTH`.
  - `RecipientRejected(Str, Int, Str)`: An envelope recipient was rejected by the server (`RCPT TO`).
  - `DataRejected(Int, Str)`: Message content or data command was rejected (`DATA`).
  - `CommandFailed(Str, Int, Str)`: General command failure when the reply code did not match expected protocol state.
  - `TimedOut`: Socket execution deadline exceeded.
  - `EmptyEnvelope`: The message contains no recipients.
- `client(host: Str, port: Int) -> SmtpClient`:
  Initializes an SMTP client target.
- `withDomain(client: &SmtpClient, domain: Str) -> SmtpClient`:
  Sets the `EHLO` identification domain.
- `withAuth(client: &SmtpClient, user: Str, pass: Str) -> SmtpClient`:
  Configures standard `AUTH LOGIN` credentials.
- `withTimeout(client: &SmtpClient, timeoutMs: Int) -> SmtpClient`:
  Sets the socket operation deadline.
- `deliver(client: &SmtpClient, message: &Mail.Message) -> Result[Int, SmtpError]`:
  Connects to the server, completes the `EHLO` handshake, authenticates if configured, issues `MAIL FROM` and `RCPT TO` for every address in `Mail.envelope(&message)`, streams the dot-stuffed RFC 5322 payload via `DATA`, and terminates with `QUIT`. Returns the count of accepted recipients.
- `parseReply(raw: Str) -> Result[SmtpReply, SmtpError]`:
  Parses multi-line or single-line RFC 5321 server replies (e.g. `250-SIZE\r\n250 HELP`).

## Governance and Algorithm

**Strict envelope separation.** Recipients listed in `blindCopies` are included in the SMTP envelope via `RCPT TO:<...>` calls but omitted from `render(&message)` header output (`To:` and `Cc:`). The transport never leaks blind copy destinations in the message payload.

**Dot-stuffing and transparency.** RFC 5321 transparency rules require that any line in the body starting with a period (`.`) is prepended with another period (`..`) during transmission so that a line with a single period followed by `\r\n` unambiguously signals the end of the message. This encoding is applied automatically by `Mail.stuffed` within `Mail.render`.

**Defensive multi-line parsing.** SMTP server greetings and `EHLO` capabilities often return multi-line responses marked by hyphens (`250-smtp.example.com\r\n250 OK`). The reader aggregates multi-line chunks until a three-digit code followed by a space indicates completion.

## Grill Log

- **Q:** Why support `AUTH LOGIN` in addition to `AUTH PLAIN`?
  **A:** While `AUTH PLAIN` is a formal RFC standard, major enterprise SMTP relays (Microsoft 365, Amazon SES, older SendGrid endpoints) widely require or default to `AUTH LOGIN` for legacy compatibility.
- **Q:** How are connection timeouts enforced?
  **A:** Every network read and write utilizes `Net.sendWithin` and `Net.receiveWithin` (or TLS equivalents) parameterized by `client.timeoutMs`, preventing unresponsive mail relays from deadlocking application worker threads.
- **Q:** What happens if one recipient is rejected in a multi-recipient message?
  **A:** If any recipient receives a 4xx or 5xx code from `RCPT TO`, the transport aborts the transaction with `RecipientRejected` and issues `RSET`/`QUIT`, guaranteeing that messages are not partially dispatched to a subset of unintended recipients without application notification.

## Referenced by

[[src/Std/_MOC]] · [[Std Mail]] · [[Std Net]] · [[Std Tls]] · [[architecture/WEB]] · [[ADR-0017 What the Web Layer Refuses]]

## Boundary completion

deliver validates Mail records and EHLO input, refuses credentials over its current plaintext transport, and closes the connection after every ordinary Result path. TLS submission is not implemented.
Resolved Grill Log: reject unsupported transport/representation behavior rather than emit corrupted output or silently weaken validation. No tests or reviews run.

Reply reads use a shared monotonic deadline and 65536-byte cap, and wait for CRLF before
recognizing a final status line. Complete SMTP multiline validation and UTF-8 fragment buffering
remain follow-up work. No live delivery was performed.

## Strict reply framing

Reply parsing requires complete CRLF lines, three ASCII digits, one consistent status code,
hyphen continuations followed by exactly one final line, and a 512-byte maximum per line.
Unexpected final lines, incomplete multiline replies and malformed separators are rejected.
Socket reads accumulate Bytes before UTF-8 decoding so split multibyte reply text is retained.
A completed reply is parsed only after its CRLF; the overall reply remains capped at 65536 bytes
and one monotonic deadline. Resolved Grill Log: packet boundaries are not text or reply boundaries.
