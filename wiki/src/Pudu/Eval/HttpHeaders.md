---
type: module
path: "@root/src/Pudu/Eval/HttpHeaders.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
aliases: [Eval Http Headers]
---
# Eval Http Headers

## Purpose

The evaluator's `httpHeaderPairs(head)` builtin, implemented by `callHttpHeaders`.

## Contract

Takes one `Str` and answers an array of `(Str, Str)` tuples, the header pairs of the head. It takes the same lines as the native kernel in [[Native HTTP Header Kernel]]: the request line is skipped, the separator is `\r\n` when the head contains one and `\n` otherwise, and blank lines are dropped.

An empty array asks the caller to read the head itself. It is the answer for a folded continuation, a line holding a carriage return or line feed, a line with no colon, a name that is not a token, and a head with no header line. Both engines give the same answer for every head, so a head the native kernel declines reaches the same Pudu reader either way.

A value of any other kind reports the builtin argument error `E7012`.

## Resolved Grill Log

Why an empty array rather than an error: a head with an unusual line is still valid input to the Pudu reader, which decides what to report and says which line is wrong. The builtin only declines.

Why the same rules in both engines: the fast path must never accept a head the line reader would refuse, nor refuse one it would accept. Sharing the token and trimming rules keeps the two answers identical.

## Referenced by

[[Native HTTP Header Kernel]] · [[Eval Builtin]] · [[Std Http Message]]
