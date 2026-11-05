---
type: architecture
status: ACTIVE_DESIGN
tags: [architecture, desktop, webview, ipc, security, packaging, updates]
aliases: [Pudu Desktop, Desktop WebView Applications]
---

# Pudu Desktop

## Purpose

Pudu Desktop builds cross-platform desktop applications whose backend is a Pudu program and whose
interface is rendered by the platform's own WebView. The Pudu program **owns** the application: it
opens windows, decides what each WebView may load and call, serves every local asset, answers every
call, and installs its own updates. A WebView is a privileged renderer — it holds no authority the
program did not grant it, and nothing it does reaches the machine except through a Pudu function.

The framebuffer desktop of [[architecture/NATIVE-UI]] remains the path for interfaces drawn in Pudu;
this page is the path for interfaces written in HTML, CSS and JavaScript. Both share the rule that
no platform value, callback or memory rule crosses into Pudu.

## Pillars and where each lives

| Pillar | Module | Contract |
| --- | --- | --- |
| Native WebView embedding | [[Std Desktop Webview]], [[Pudu Webview Adapter]], [[Eval Webview]] | windows hold one or more WebViews; every operation is a typed result; an unsupported target answers `UnsupportedPlatform` |
| Local assets | [[Std Desktop Protocol]] | the `pudu://app/` origin is served by the program from a directory or a packed archive, never from the file system directly |
| Typed IPC | [[Std Desktop Ipc]], [[Std Desktop Shape]], [[Std Desktop Bridge]] | commands are typed Pudu functions; arguments decode or are refused with a path; TypeScript definitions are generated from the same types |
| Security | [[Std Desktop Capability]] | deny by default; grants name WebViews, origins, commands and argument scopes; deny beats allow |
| Plugins | [[Std Desktop Plugin]] | a plugin declares its permissions and is refused whole when one is not granted |
| Developer experience | [[Std Desktop App]], [[Std Desktop Cli]] | one run loop; dev mode reloads the frontend on change and the backend through `pudu run --watch`; console errors cross back with their source position |
| Packaging | [[Std Desktop Bundle]] and its format modules | `.app`, `.dmg`, `.deb`, `.rpm`, AppImage, NSIS and MSI from one `pudu-desktop.toml` |
| Updates | [[Std Desktop Update]], [[Std Desktop Delta]], [[Std Crypto Sign]] | signed manifests, channels, background checks, block-level patches, staged installs with rollback |

## The native boundary

One adapter per platform implements a single C ABI ([[Pudu Webview Adapter]]). The ABI is a
**record channel**, not a function per feature: the program sends batches of commands, pumps the
platform loop, and drains events. Six entry points carry everything:

| Entry point | Direction | Meaning |
| --- | --- | --- |
| `pudu_webview_send` | program → platform | apply a batch of command records in order; stop at the first that fails |
| `pudu_webview_pump` | program → platform | run the platform loop until an event is queued or the slice ends |
| `pudu_webview_events` | platform → program | measure, then copy and clear, the queued event records |
| `pudu_webview_body` | platform → program | copy one pending request's body |
| `pudu_webview_respond` | program → platform | finish one pending request with status, headers and body |
| `pudu_webview_failure` | platform → program | the reason the last refused command gave |

A record is a run of **length-prefixed fields** — `<decimal byte length>:<bytes>,` — ending in a
line feed. Script source, HTML and URLs routinely contain tabs and newlines; a length prefix carries
them unescaped and lets the C side read a field without scanning it twice. The same framing is used
in both directions.

### Commands

`window <id> open <title> <width> <height> <resizable>` · `window <id> title|size|min-size|max-size|position|center|show|hide|focus|fullscreen|close …` ·
`view <id> create <window> <x> <y> <width> <height> <fill>` followed by configuration records
(`view <id> url|html|devtools|user-agent|zoom|data-store|navigation-allow|script|style|rules|csp|transparent …`) and a closing
`view <id> realize` · `view <id> navigate|reload|back|forward|stop|eval|bounds|zoom|user-agent|devtools-open|devtools-close|show|hide|focus|close …`.

Configuration is separate from realization because a platform WebView fixes its scripts, rule
lists, data store and inspectability when it is created; collecting them first makes "configure,
then realize" the only order the adapter accepts.

### Events

`close-requested <window>` · `resized <window> <w> <h>` · `moved <window> <x> <y>` · `focused <window> <0|1>` ·
`request <view> <id> <method> <url> <header block> <body length> <page url>` · `loaded <view> <url>` ·
`navigated <view> <url>` · `navigation-blocked <view> <url>` · `new-window-blocked <view> <url>` ·
`title <view> <text>` · `eval <view> <ticket> <ok|error> <json or message>` ·
`rules <view> <ready|failed> <detail>` · `crashed <view>`.

### Threading and latency

The platform loop runs on the process's main thread, which is the thread the evaluator runs `main`
on. A pump returns as soon as an event is queued — the adapter posts a wake-up event to the loop
when it queues one — so an IPC round trip costs one pump turn, not a fixed frame interval. A pump is
sliced exactly as the framebuffer pump is, so an interrupt is answered within a slice.

## The `pudu://` origin

Every WebView loads the application from `pudu://app/` and calls the program through
`pudu://app/.pudu/ipc/<command>` — the same origin, so a call needs no cross-origin preflight. Both are served by the program: the adapter turns each request into a `request`
event and holds it until `pudu_webview_respond` finishes it. Serving through the program rather
than through `file://` gives one origin with a stable identity, response headers the program sets
(`Content-Security-Policy`, `Content-Type`, caching), and no path on disk that a page can name.

- Asset paths resolve inside the asset root ([[Std Desktop Protocol]] `resolveAsset`); `..`,
  absolute paths, NUL and backslashes are refused before any file is touched.
- A directory path serves its `index.html`; a missing path in a single-page application serves the
  configured fallback.
- The default policy is `default-src 'self' pudu:; script-src 'self'; style-src 'self' 'unsafe-inline';
  img-src 'self' pudu: data: blob:; connect-src 'self' pudu:; object-src 'none'; base-uri 'self';
  frame-ancestors 'none'`. An application widens it explicitly.

## Typed IPC

A command is a Pudu function from a decodable argument record to an encodable result:

```pudu
type Greeting = { text: Str, count: Int } derives Json.Encode, Shape.Describe
type GreetArgs = { name: Str } derives Json.Decode, Shape.Describe

fn greet(args: GreetArgs, call: &Ipc.Call) -> Result[Greeting, Ipc.Failure] { … }

let commands = Ipc.commands().with(Ipc.command("greet", greet))
```

- **Invoke.** The bridge posts JSON (or raw bytes for a binary command) to `pudu://app/.pudu/ipc/<name>`.
  The program decodes, checks capability, runs the function and answers `200` with the result or an
  error status with an envelope `{ kind, message, command, path }`. `kind` is one of
  `unknown-command`, `denied`, `invalid-arguments`, `failed`, `internal`.
- **Binary.** A raw command receives and answers `Bytes`; the bridge passes an `ArrayBuffer` or
  typed array as the body and receives an `ArrayBuffer`. Nothing is base64-encoded.
- **Events.** The program emits named JSON events to one WebView or all; the bridge delivers them to
  `listen` handlers. The frontend emits events back through the reserved command `pudu:emit`.
- **Channels.** A frontend `Channel` travels with a call in the `Pudu-Channel` header; a
  `streamCommand` receives it as a typed `Stream[M]`, posts messages the bridge delivers in order,
  and closes it with `finish`. This is the
  path to streams: a command that produces many values returns once and sends the rest.
- **Errors across the boundary.** A failed invoke rejects with a `PuduError` carrying `kind`,
  `command`, the decoding `path`, and the Pudu message. Uncaught frontend errors, rejected promises
  and `console.error` are forwarded in development to the program, which prints them with their
  source URL, line and column.
- **Call origin.** The bridge records its document's origin when it is injected and sends it with
  every call; a call whose origin is not the view's current page is refused, so navigation cannot
  move a call in flight to another origin's capabilities.
- **Invoke key.** Each WebView receives a fresh random key in its injected bridge and every IPC
  request must carry it, so a page that did not receive the bridge — a frame from another origin, a
  page navigated to by mistake — cannot call the program even when the capability would allow its
  origin.

### Generated TypeScript

[[Std Desktop Shape]] describes a type's wire form as a `Shape` value — the same form `Json.Encode`
writes, so a record is an object, an `Option` is `T | null`, `Bytes` is an `ArrayBuffer`, and a sum
is a one-key object per variant. `derive Describe` produces it for records and sums.
`Ipc.typescript(&commands)` writes a module with every named type and a typed function per command,
so a renamed field is a compile error in the frontend, not a runtime surprise. `pudu desktop types`
runs the application with `PUDU_DESKTOP_TYPES=<path>`; `App.run` writes the module and exits
without opening a window.

## Security model

- **Capabilities** ([[Std Desktop Capability]]) are values: an identifier, the WebView labels and
  origin patterns they apply to, and the permissions they grant. A permission names a command and an
  optional scope (allowed and denied argument patterns, matched with [[Std Glob]]). A WebView in
  several capabilities holds their union; any deny wins; nothing is granted by default.
- **Origins.** Bundled pages are `pudu://app`. A remote origin may call the program only when a
  capability names it; development servers are admitted only in dev mode.
- **Isolation.** Each WebView has its own data store, keyed by its label, so storage, cookies and
  caches are never shared unless two WebViews name the same store. A WebView marked `ephemeral` keeps
  nothing.
- **Navigation.** A WebView may navigate only to its own origin and the patterns its configuration
  allows; any other navigation is cancelled and reported as `navigation-blocked`, and a request to
  open a new window is cancelled and reported, so the program may open it in the system browser.
- **Rules before content.** A view's initial page loads only after its content rules compile; a
  rule list that fails leaves the view empty rather than unfiltered.
- **Plugins** cannot widen any of this: a plugin's permissions must be granted by the application,
  and its injected code runs in the page, never in the program.

## Plugins

A plugin ([[Std Desktop Plugin]]) is a value: a name, declared permissions, injected scripts and
styles with URL patterns and injection time, request-blocking rules, and navigation hooks. Loading
checks every declared permission against the application's grants and refuses the plugin whole with
the missing permissions named. Request blocking compiles to the platform's declarative content-rule
format, so a blocked request never leaves the WebView and no per-request round trip to the program
is paid. Injected code is wrapped so it runs only where its patterns match.

## Developer experience

- `pudu desktop init <dir>` writes a working application: `pudu-desktop.toml`, `src/Main.pudu`,
  `frontend/index.html`, a capability file and generated types.
- `pudu desktop dev` runs the program under `pudu run --watch` with `PUDU_DESKTOP_DEV=1`; the run
  loop then enables the inspector, forwards console errors, and watches the frontend directory —
  a stylesheet change swaps styles in place, any other change reloads the page.
- `pudu desktop types`, `build`, `bundle`, `keygen`, `sign` and `manifest` cover the release path.

## Packaging

`pudu-desktop.toml` is the single declaration. `pudu desktop bundle` builds the program into one
executable, packs the frontend, and writes each requested format ([[Std Desktop Bundle]]):

| Target | Produced by | Signing |
| --- | --- | --- |
| `.app` | written directly: layout, `Info.plist`, icon, executable, packed assets | `codesign` with hardened runtime and entitlements; notarization and stapling through `notarytool` |
| `.dmg` | `hdiutil` over a staging folder with an Applications link | the image is signed like the app |
| `.deb` | written directly: `ar` of `debian-binary`, `control.tar.gz`, `data.tar.gz` | detached signature by `gpg` |
| `.rpm` | written directly: lead, signature header, header, gzip cpio payload | header SHA-256 digest; detached `gpg` signature |
| AppImage | AppDir written directly; image by `appimagetool` | detached `gpg` signature |
| NSIS `.exe` | script written directly; installer by `makensis` | `signtool` or `osslsigncode` |
| MSI | source written directly; installer by `wix` | `signtool` or `osslsigncode` |

A tool a format needs that is not installed is a typed `ToolMissing` naming it; nothing is
skipped silently.

Every package ships the runtime executable unmodified and the program beside it as
`<executable>.pudub` (in `Contents/Resources` on macOS). A signed executable cannot carry bytes after
its image, so the program travels as a resource the signature seals; the runtime reads the sidecar
when nothing is attached to it ([[Pudu Bundle]]). Asset optimization packs the frontend into one gzip archive served from memory,
drops source maps from release builds, and strips the executable's symbols.

## Updates

- The manifest is JSON: `version`, `notes`, `published`, `channel`, and `platforms` keyed
  `<os>-<arch>`, each with `url`, `size`, `sha256`, `signature`, and optional `patches` from earlier
  versions. An endpoint answering `204` has no update.
- Endpoints may write `{{target}}`, `{{arch}}`, `{{current_version}}` and `{{channel}}`.
- Channels are ordered `stable` < `beta` < `nightly`; a subscriber accepts its own channel and every
  more stable one.
- Every artifact is verified by size, SHA-256 and an Ed25519 signature made with the key whose public
  half the application embeds. Verification cannot be turned off.
- A patch ([[Std Desktop Delta]]) is tried first when one is offered from the running version; the
  rebuilt artifact must hash to the full artifact's SHA-256, and any failure falls back to the full
  download.
- Installation is staged: the new version is unpacked beside the old, swapped in by rename, and
  marked pending. The next start that calls `Update.confirm()` makes it permanent; a start that
  finds a pending install that was never confirmed restores the previous version.
- `Update.background` checks and downloads on a worker thread and reports through a channel the run
  loop polls, so the interface never blocks on the network.

## Platform status

| Target | Adapter | Status |
| --- | --- | --- |
| macOS | WebKit through AppKit | **Ready**; driven live by [[Desktop Webview Gate]] and [[Desktop Webview CI]] |
| Linux | WebKitGTK | **Ready** behind the `webkitgtk` cabal flag; [[Desktop Webview CI]] drives it under a virtual display |
| Windows | WebView2 | **Absent**: answers `UnsupportedPlatform`; the adapter contract is the six entry points above |

## Referenced by

[[architecture/_MOC]] · [[architecture/NATIVE-UI]] · [[decisions/ADR-0026-a-webview-is-a-renderer]] · [[handoffs/2026-11-05-pudu-desktop]]
