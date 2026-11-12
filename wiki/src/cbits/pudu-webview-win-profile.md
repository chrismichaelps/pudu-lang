---
type: module
path: "@root/cbits/pudu_webview_win_profile.cpp"
fidelity: Active
aliases: [Pudu Webview Windows Profile]
tags: [module, runtime, desktop, windows, isolation]
---
# Pudu Webview Windows Profile

## Purpose and interface

Decide where a WebView2 view's storage lives before any native realization begins.
`pudu_private_storage(view)` is true for an `ephemeral` view and for a view without an explicit
store label. `pudu_profile(view, profile)` resolves the per-user local data folder and the
program's file name, then returns either the shared private folder or the verified folder of a
named store. `pudu_private_profile_name()` gives each private native view its own profile
identity. `pudu_store_digest(label)` is the store's folder name.

## Semantics

Layout under `%LOCALAPPDATA%\<program>\webview\2\`:

| Folder | Holds | Identity |
| --- | --- | --- |
| `private` | The browser process of every private view | One distinct in-memory profile per native view; nothing is kept |
| `stores\<64 hex>` | One explicitly named store | SHA-256 of the exact label bytes, confirmed by the `pudu-store` file |

- **Inputs fail closed.** A missing, empty, relative, or changed-between-reads `LOCALAPPDATA`
  refuses with Platform. The variable is read at its reported length, never truncated to a fixed
  buffer. The program path is read with a growing buffer; a failed, truncated, or nameless path
  refuses. No refusal leaves the view realizing.
- **Explicit sharing only.** Two views share persistent storage only when both name the same
  label. Unnamed views are private, so no implicit label exists to alias. A label spelled
  `default` is an ordinary named store, distinct from every private view.
- **Identity verification.** A store folder's `pudu-store` file holds a version line and the
  exact label. A new folder receives the file with exclusive creation; an existing file must
  match byte for byte. A mismatch, an unreadable or oversized file, or a folder path that is not
  a directory refuses instead of attaching.
- **Versioned namespace.** The `2` segment separates this layout from the earlier
  `webview\<16 hex>` folders, whose 64-bit label digest cannot prove identity and whose
  `default` folder mixed every unnamed view. Those folders are never opened; their data stays on
  disk, unused.
- **Private identity.** A private profile name joins the process id and a per-process admission
  counter, so concurrent private views in one process, or in two processes sharing the folder,
  never share a session.

## Grill Log

- **Q:** Why a separate unit? **A:** Storage identity is a security decision made before the
  environment exists and tested without a renderer. The environment unit keeps scheme
  registration and loading; this unit owns paths and identity.
- **Q:** Why are unnamed views private rather than one shared default? **A:** The isolation
  contract shares only on explicit naming. A shared default makes every unnamed view an implicit
  sharer, the same defect application namespacing removed at the App layer.
- **Q:** Why SHA-256 plus an identity file? **A:** The digest makes accidental aliasing
  impractical; the file turns the remaining possibility, or a folder planted under the expected
  name, into a refusal instead of a silent attach.
- **Q:** Why keep private views in one folder? **A:** A folder is a browser process. One per view
  multiplies processes and leaves folders behind; distinct private profiles inside one folder
  already separate sessions without persisting anything.
- **Q:** What about legacy folders? **A:** They are bypassed, not migrated. Their contents may
  belong to any unnamed view, so migrating them would carry the aliasing forward.
- **Q:** Does WebView2 accept different options for one folder? **A:** No. Environments sharing a
  folder must use equal options, including scheme origins. A conflicting request fails
  asynchronously and is reported as a refusal; it never falls back to another folder.

## Dependencies and consumers

Uses [[Pudu Webview Windows Host]]; hashes with the platform certificate library, already linked
by [[Pudu Cabal Manifest]]. Called by [[Pudu Webview Windows Environment]]. Verified by
[[Webview Windows Profile Harness]] and run by [[Desktop Webview CI]].

## Referenced by

[[src/cbits/_MOC]] · [[Pudu Webview Windows Environment]] · [[Pudu Webview Windows Host]] ·
[[Webview Windows Profile Harness]] · [[architecture/DESKTOP-WEBVIEW]]
