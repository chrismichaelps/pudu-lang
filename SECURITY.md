# Security policy

## Reporting a vulnerability

Report a suspected vulnerability privately through GitHub's
[security advisory form](https://github.com/chrismichaelps/pudu-lang/security/advisories/new), or by
email to <chrisperezsantiago1@gmail.com> with `SECURITY` in the subject.

Please do not open a public issue for a vulnerability. A public report tells everyone how to use the
problem before there is a version that fixes it.

Include what you need to make the problem happen again: the version `pudu version` prints, the
platform, and the smallest program that shows it. A proof of concept is welcome and is never
required.

You can expect an acknowledgement within seven days and a decision on whether the report is accepted
within thirty. Pudu is maintained by one person, so an acknowledgement may be all that arrives while
the report is still being investigated.

## What is in scope

Pudu runs programs and ships a standard library that speaks to the network, the filesystem, and
databases. A report is in scope when it lets a program do something its source does not say it does,
or lets input decide something the program never gave it. That includes:

- The compiler or evaluator running code a program's source does not contain.
- A standard library reader that a crafted input drives out of its bounds, into unbounded memory, or
  into a hang.
- `Std.Tls` accepting a certificate it should reject, or failing to verify a chain or hostname.
- `Std.Db` placing a parameter into statement text rather than binding it, or a pool handing one
  borrower's transaction to another.
- `Std.Http.Server` mixing one connection's request or response with another's.
- A cryptographic routine that does not compute what it is named for.
- The published archives or the release workflow shipping something other than what the tagged
  source builds.

## What is not in scope

- A program that is given a capability and uses it. A signature says what a function may do, and a
  program that opens a socket or reads a file is doing what it was written to do.
- Resources that rely on an explicit `close`. Several opaque resources still need one, cancellation
  does not yet propagate between workers, and this is recorded as open work in
  [`wiki/architecture/RELEASE-READINESS.md`](wiki/architecture/RELEASE-READINESS.md) rather than
  treated as a vulnerability.
- Denial of service by simply providing more input than a machine has memory for, on a reader whose
  bounds have not been measured yet. The readers whose memory is proven flat are named in the
  readiness document; the others are open work.
- Findings in third-party libraries reached through the foreign boundary. Report those upstream; if
  the binding is what makes the problem reachable, that part is in scope.

## Supported versions

| Version | Supported |
| ------- | --------- |
| 0.1.x   | Yes       |

Pudu is pre-release. Fixes land on the next version rather than being backported, and there is no
long-term support branch yet. When a release fixes a vulnerability its notes say so, and the advisory
is published on the repository's security page.
