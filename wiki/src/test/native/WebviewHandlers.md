---
type: module
path: "@root/test/native/WebviewHandlers.cpp"
fidelity: Active
aliases: [Webview Windows Handler Harness]
tags: [module, test, desktop, windows, ownership]
---
# Webview Windows Handler Harness

## Purpose and interface

Exercise the production handler factory using the actual SDK completion interface. A captured
shared token makes callback destruction observable without accessing its internal reference count.
Failed and synchronous registration must release the creation reference at expression end; an
asynchronous registration retains its own reference until completion/teardown. QueryInterface
references remain independently releasable. Named/moved owners must release exactly once.

## Grill Log

- **Q:** Why test ownership without a renderer? **A:** The defect is the factory's creation
  reference, which exists before any runtime call. A controlled COM consumer makes both retaining
  and rejecting paths deterministic and directly observes captured-resource destruction.
- **Q:** Should a new handler start with reference count zero? **A:** No. Its scoped creation owner
  releases the initial reference; a consumer owns only references it explicitly retains.

## Dependencies and consumers

Uses [[Pudu Webview Windows Host]] and the shipped SDK. Run by [[Desktop Webview CI]].

## Referenced by

[[src/_MOC]] · [[Pudu Webview Windows Host]] · [[Desktop Webview CI]]

Resolved Grill Log: interface queries use the production SDK wrapper rather than an external forced include.
