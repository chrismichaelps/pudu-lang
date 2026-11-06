---
type: module
path: "@root/lib/Std/Desktop/Bundle/Windows.pudu"
fidelity: Active
domain: "[[Pudu Program]]"
subsystem: "[[Standard Library]]"
grammar: "[[grammar/pudu]]"
tags: [module, stdlib, desktop, packaging, windows]
aliases: [Std Desktop Bundle Windows]
---

# Std Desktop Bundle Windows

## Purpose and interface

Windows installers. `nsisScript` writes an NSIS script and `nsis` compiles it with `makensis`;
`wixSource` writes a WiX source and `msi` builds it with `wix`; `numericVersion` gives the four-part
version installers require; `upgradeCode` derives a stable GUID; `signed` applies Authenticode.

## Semantics

- Both installers install per user under `%LOCALAPPDATA%\Programs\<Name>` without elevation, place
  the executable and `app.tar.gz` side by side, add a Start-menu shortcut, and register an uninstall
  entry under the application identifier.
- The NSIS installer checks the registry for the WebView2 runtime and tells the person how to get it
  when it is absent; its uninstaller removes exactly what was installed.
- `numericVersion` keeps the semantic version's major, minor and patch and appends `0`; prerelease
  and build labels are dropped because the installer formats accept only numbers.
- Without a configured upgrade code, `upgradeCode` derives one from the SHA-256 of the identifier,
  so successive versions of one application upgrade each other.
- Signing uses `signtool` when installed and `osslsigncode` otherwise, with SHA-256 digests and an
  RFC 3161 timestamp; the certificate password comes from `PUDU_DESKTOP_CERTIFICATE_PASSWORD`.

## Grill Log

- **Q:** Why per-user installs? **A:** They need no administrator approval and let the updater
  replace files in place; a machine-wide install is a separate decision an application can make by
  editing the generated source.

## Dependencies and consumers

Uses [[Std Desktop Bundle Config]] and [[Std Semver]]. Consumed by [[Std Desktop Bundle]].

## Referenced by

[[src/Std/_MOC]]
