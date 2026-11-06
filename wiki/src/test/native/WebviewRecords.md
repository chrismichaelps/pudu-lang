---
type: module
path: "@root/test/native/WebviewRecords.c"
fidelity: Active
aliases: [Webview Records Test]
tags: [module, test, desktop, webview]
---
# Webview Records Test

Checks [[Pudu Webview Records]] without a display: framing round trips with empty and control
characters, every malformed shape (no length, short data, missing comma, unterminated, empty
record, overlong length, too many fields), buffer measuring and short-capacity drains, NUL refusal,
and URL patterns including a wildcard that would otherwise cross a slash, a query or user-info.

## Referenced by

[[Desktop Webview Gate]] · [[Desktop Webview CI]]
