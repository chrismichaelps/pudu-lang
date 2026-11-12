---
type: module
path: "@root/lib/Std/Desktop/Plugin.pudu"
fidelity: Active
domain: "[[Pudu Program]]"
subsystem: "[[Standard Library]]"
grammar: "[[grammar/pudu]]"
tags: [module, stdlib, desktop, plugins, security]
aliases: [Std Desktop Plugin]
---

# Std Desktop Plugin

## Purpose and interface

Small libraries that extend what a view does. A `Plugin` declares `permissions` and carries
injected `scripts` and `styles` with URL patterns, request-blocking `rules`, and navigation hooks.
`required` lists what its contents need; `check` admits it against the application's granted
permission names; `apply` adds every admitted plugin's contents to a view; `navigated` collects the
hooks' commands for a navigation; `rulesJson` writes the platform's content-rule list;
`parsePermission` and `permissionName` translate permission names through a const factory table.

## Semantics

- Permissions: `inject-script`, `inject-style`, `modify-content` (a script that changes the page
  after it loads), `block-requests`, `observe-navigation`, and `invoke:<command>`.
- `check` fails with `MissingPermission` when the plugin uses something it did not declare, and
  `NotGranted` naming every declared permission the application did not grant. A plugin is
  admitted whole or not at all.
- Injected code runs only where a pattern matches `location.href`; no patterns means every page.
  Patterns are globs translated to anchored regular expressions with every other character literal;
  `*` matches any run in the path, but in the scheme and authority it cannot cross `/`, `?`, `#` or
  `@`, so `https://*.example.com/*` never admits `https://evil.test/x.example.com/`.
- Styles are delivered as document-start scripts that add a `style` element where they match.
- Rules compile to the platform's declarative format: `block`, `block-cookies`,
  `css-display-none` with a selector, and `make-https`, each with a URL filter, optional resource
  types and optional domains. Blocking happens inside the WebView, with no round trip to the program.

## Grill Log

- **Q:** Why must a plugin declare permissions its contents already imply? **A:** The declaration is
  what the application's author reviews and grants; deriving it would let a plugin update widen its
  reach without the grant changing.
- **Q:** Why declarative rules instead of asking the program per request? **A:** A per-request round
  trip would put every image and script behind the program's loop; declarative rules block before
  the request leaves the WebView and cannot be slowed by the program.

## Dependencies and consumers

Uses [[Std Desktop Webview]] and [[Std Json]]. Consumed by [[Std Desktop App]].

## Referenced by

[[src/Std/_MOC]] · [[architecture/DESKTOP-WEBVIEW]]

Resolved Grill Log: rulesJson emits url-filter-is-case-sensitive:true explicitly, preserving the same literal glob case behavior as guarded scripts on every native platform.
