---
type: module
path: "@root/packages/pudu/v0.1/android/org/pudu/PuduFiles.java"
fidelity: Active
subsystem: "[[Backend]]"
tags: [module, native, android, files]
aliases: [PuduFiles]
---

# PuduFiles

## Purpose and interface

The read-only content provider through which the Android host shares files of the application with other applications (#994). It is declared in the application manifest with the authority `<package>.files`, not exported, and with `grantUriPermissions` set to true. Another application can therefore read a file only through the URI permission that a share grants. The provider serves only files whose canonical path lies inside the application's cache directory. [[PuduCompose]] builds the URI for SHARE_FILE.

## Behavior

- A URI names one file under the cache directory through the authority. Opening it for reading returns the file's bytes.
- Opening a URI whose canonical path is outside the cache directory fails.
- Insert, update and delete are not supported, so the provider never writes.

## Invariants

- The canonical path is resolved before the containment check. Symbolic links and `..` segments that leave the cache directory are refused.
- Read access only.
- The provider is not exported, so other applications reach it only through a grant this application makes.

## Negative Logic

- No directory listing. A URI names a single file.
- No file outside the cache directory. The files directory, databases and preferences are never served.
- No write path.

## Dependencies and consumers

Depends on the Android content provider base class, the cache directory of the application context, and the provider declaration in the application manifest (authority, not exported, grant URI permissions). Consumers: [[PuduCompose]], which builds the URI for SHARE_FILE. The program reaches it through [[Std Mobile System]] (`shareFile`). Its source is listed with the other Android sources in [[Pudu/Backend/Toolchain/HostSources]]. Example: [[Outbox Example]].

## Resolved Grill Log

- **Q:** Why a provider rather than a file URI? **A:** Android refuses file URIs across applications. A provider with a URI grant lets the receiving application read one named file for the duration of the share.
- **Q:** Why only the cache directory? **A:** The cache directory holds files made for handing out, such as the copies the pickers make in [[PuduPick]]. Nothing else is shared, so a crafted path cannot expose other data of the application.
- **Q:** Why check the canonical path rather than its prefix? **A:** A prefix check accepts `..` segments and symbolic links that leave the directory. The canonical path resolves both before the check.

## Referenced by

[[PuduCompose]] · [[pudu-android-services]] · [[Std Mobile System]] · [[Std Mobile Compose]] · [[PuduPick]] · [[HostSources]] · [[Outbox Example]] · [[NATIVE-MOBILE]]
