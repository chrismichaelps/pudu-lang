---
type: handoff
status: ACTIVE
issue: 193
tags: [handoff, release, stdlib, ui]
---

# Release Readiness and Native UI Canvas

## Objective

Correct the stale first-release table against implemented behavior, then begin the explicitly desired
native application UI/audio/video row. Raylib and Apple publications are architecture and
performance references only: this implementation uses no foreign integration and exposes no
game-engine or platform-framework vocabulary. Work is
committed directly to `dev` at the user's explicit direction; no branch or PR is created.

## Ownership and roles

1. **Language Architect:** owns [[First Release Readiness]], [[Native Application UI]], and the
   Pudu-native/no-foreign boundary.
2. **Stdlib Implementer:** owns `packages/pudu/v0.1/lib/Std/Ui/Canvas.pudu`,
   `packages/pudu/v0.1/lib/Std/Ui/Layout.pudu`, `test-fixtures/stdlib/UsesUiCanvas.pudu`,
   `test-fixtures/stdlib/UsesUiLayout.pudu`, their mirrors, and the exact-count service fixture
   registrations.
   The current presenter slice additionally owns `Std/Ui/Desktop.pudu`, `Pudu/Eval/Desktop.hs`,
   the private macOS adapter, launch fixtures, and their complete mirrors.
3. **Validation:** focused fixtures and `test/gates.sh` protect each slice. Further review sub-agents
   are disabled at the user's explicit direction.

The active role returns to **Language Architect** for [[Desktop Capability Conformance]], then to
**Stdlib Implementer** for `examples/media/Studio.pudu` and its mirror. This iteration changes no
shared compiler or standard-library contract; it exercises the already committed UI/audio/video
surface and records every missing desktop domain it exposes.
After implementation, the active role transitions to **Validation** for formatter, focused fixture,
WAV structure, real-window launch, and full-suite evidence.
The installed-command failure transitions the active role to **Build/Release Engineer**, owning
`packages/pudu/v0.1/pudu.cabal`, root `pudu-tests.cabal`, `cabal.project`, their mirrors, and install/
source-archive gates. This bounded repair does not alter compiler or media semantics.

Other work exists in the repository. This slice does not alter the preserved untracked website probe
or the commits on `feature/228-std-prose`.

## Contract

`Std.Ui.Canvas` is a bounded Pudu-native RGBA software renderer. It owns pure geometry, a flat ordered
fill list, overflow-safe clipping, opaque replacement, integer source-over blending, and exact
framebuffer inspection. It neither opens a window nor binds a native toolkit. It rasterizes by bands
and spans, and `repaint` redraws damaged regions with byte equality to `render`.

`Std.Ui.Layout` is the declarative layer above it: `View` values with modifiers as fields, two-pass
placement, exact grow distribution, a semantics tree that refuses unnamed meaningful roles, focus
order, hit testing, painting, and damage regions.

## State

- `bc50f06` — exact-pixel canvas and the corrected readiness audit.
- `fd6cfd3` — band-and-span rasterizer and repaint; 512×512 frame 4.35 s → 0.10 s at -O2.
- `a1cb1c5` — declarative layout; 1,001 nodes place in about 0.18 s and paint plus render in about
  0.56 s at -O2, which is interpreter cost and not yet an interactive frame.
- `2b45bea` — `Std.Ui.Screen` routes presses and action keys to tagged controls and repaints only
  damage; layout gained tags. Layout 33 and screen 16 assertions.
- `a1d9181` — `Std.Ui.Text` original bitmap face, 21 assertions; canvas span search makes a
  400-character paragraph draw and render in 1.40 s (from 3.22 s).
- `3567c73` — layout text leaves with extent-based damage (40 assertions) and visible recolorable
  focus rings on screens (20 assertions).
- `c1eebc5` — `Std.Audio` exact byte-backed PCM, time, gain, mix, slices, and WAV (30 assertions).
- `47feac0` — `Std.Audio.Graph` stateless pull-model nodes with slice-independent renders (21).
- `749c84a` — `Std.Video` exact timing and tracks (19); screens skip unchanged views (21).
- `8b724f8` — the canvas never composes commands under an opaque region-covering command (43);
  300 stacked fills render in 0.14 s instead of 4.38 s.
- `e74ccd1` — typed text and erasing reach only a focused field (screen 27).
- `52ed91c` — windowed scroll stacks with clips for painting, hit testing, and damage (layout 46,
  text 22).
- `1405cbb` — clamped `ScrolledTo` events for the tagged scrolling node under the pointer (screen 31).
- Resampling slice — exact resampling, downmix, upmix, and channel maps (audio 42).
- Crypto breadth slice — SHA3-256/512, BLAKE2b-256/512, HMAC-SHA512, constant-time byte comparison,
  and secure key/nonce generation; crypto 59 assertions and the optimized full gate pass.
- Native desktop slice — `Std.Ui.Desktop` owns checked window plans and explicit open/present/pump/
  close sessions; the evaluation-local store serializes use against close and tears down leaks. A
  private macOS AppKit/CoreGraphics adapter exposes no framework value to Pudu and links no foreign
  UI toolkit. `LaunchUiDesktop.pudu` opened, displayed, pumped, and closed a real 480×280 titled
  desktop window with `Ok(1)`. The full Cabal suite passed after integration.
- Media laboratory slice — [[Desktop Capability Conformance]] records desktop behavior as observable
  capabilities rather than an AppKit symbol clone. `examples/media/Studio.pudu` now accepts a nested,
  bounded JSON workload and writes machine-readable timing and capability evidence. The configured
  device run launched a real 480×270 window, presented 30 pictures at 30000/1001 timing, rendered
  16,016 stereo frames in 2,048-frame slices, wrote a structurally valid 16 kHz PCM WAV, and closed
  cleanly. The initially measured 13.4-second audio preparation blocker was replaced with exact
  compiled tone/ramp byte kernels; repeated configured runs now prepare the same 16,016 stereo frames
  in 54–55 ms. Eight headless configuration assertions cover success, type, range, path-containment,
  device-queue, and duration failures.
- Device-audio slice — `Std.Audio.Device` admits bounded one-shot playback plans; its private macOS
  Audio Queue adapter preallocates two to eight buffers, refills outside the callback, uses atomic
  callback bookkeeping and a monotonic deadline, and disposes every queue. A 4,000-frame fixture and
  the 16,016-frame Studio workload both returned exact callback-acknowledged counts through the real
  default output device. The conformance state is `PARTIAL`: streaming sessions, discovery,
  interruption/device-loss, underrun telemetry, volume, shared clocks, and other OS adapters remain.
- Packaging repair — the installed compiler that first ran Studio was stale and lacked `renamePath`
  and desktop builtins; the ordinary reinstall then failed because the production package named
  `../../../test`. Tests now live in a separate root `pudu-tests` package while the compiler source
  archive is self-contained. Both manifests pass `cabal check`, `cabal sdist pudu` and
  `cabal install exe:pudu` succeed, all 70 Haskell test modules compile and the full suite passes.
  The refresh proof accepts the byte-identical `~/.cabal/bin` and `~/.local/bin` symlinks and proves
  the path-resolved compiler through language, REPL, and LSP runs. The installed compiler then ran
  the configured Studio, presented all 30 frames, and returned `Ok(30)`.
- Device-audio and preparation repair — `Std.Audio.Device` now owns a bounded default-device clip
  contract; the private macOS Audio Queue adapter preallocates every buffer, keeps the callback to
  atomic bookkeeping, applies a monotonic deadline, and disposes on every outcome. The installed
  compiler acknowledged 16,016 exact frames through the real device and presented all 30 pictures.
  Pure compiled tone/ramp byte kernels reduced the same graph preparation from 13,401 ms to 52–55 ms
  while the exact 21-check graph fixture remained unchanged. The unrestricted full suite passes;
  the earlier `UsesNet` count of one was reproduced only under a sandbox that blocks loopback and
  passes at its exact count of 22 under the release environment. PATH copies are byte-identical.
- Release hardening — the active role transitions to **Validation** for a first-release audit of
  media, UI, and the standard library, committed directly to `dev` in reviewable slices:
  `1a1bbc3` device playback lands with pure kernels classified as pure, and the queue flushed and
  drained before success so the final buffers are heard; `63397f3` desktop pumping becomes a safe
  foreign call; `376a493` extreme audio positions and record-built zero video rates are refused rather
  than trapping; `367365c` JSON decoding is linear and nesting past 512 levels is `TooDeep`; `74c5a4d`
  hex and base64 codecs are linear; `aa5c766` empty unified-diff hunk sides are numbered as `patch`
  reads them; `fb728db` empty-filler padding no longer hangs and `Std.Text` scans are linear;
  `5a92c0e` CSV reading is linear; `ae945e2` XML and TOML nesting is bounded. The HTTP slice refuses a
  transfer encoding not ending in `chunked` and a non-UTF-8 head or body. Every slice kept its exact
  fixtures and added claims for the defect it fixed; the optimized suite, formatter, checker,
  diagnostic-code, API-coverage, and LSP gates pass. `Std.Text` and `Std.Xml` gained missing mirrors.
- Audit findings left open, each a named gap rather than a silent one: the one-shot device play is
  not cancellable before its 60-second deadline; `Std.Http.Server` requests carry no byte body, so
  binary uploads are refused rather than delivered; `Std.Toml.Read` still reads characters by
  position; `Std.Mime`, `Std.Log`, `Std.Url.decodeComponent`, and `Std.Http.formDecode` still append
  per character on inputs that are normally short; a unified diff does not mark a missing final
  newline; and `Str.charAt` walks the UTF-8 prefix, so any positional scanner a program writes grows
  with the square of its text.

## Exact next action

Give `Std.Http.Server` requests an exact byte body beside the text body so multipart uploads of
binary files are delivered, then convert `Std.Toml.Read` to the cursor pattern `Std.Json` uses and
add a cancellation path to device playback before the streaming session. After those, continue the
native media roadmap: a persistent Pudu-owned stream with negotiated format, device change,
interruption, underrun telemetry, pause/resume/volume, and one observable media clock that picture
presentation follows; then the first Pudu **space** application loop over [[Std Ui Desktop]] and
[[Std Ui Screen]], translating native pointer/key/text/close events into screen inputs. Keep every
exact fixture as the semantic oracle and add percentile latency/memory gates before claiming
interactive or real-time performance.

## Grill Log

- **Q:** Link raylib? **A:** No. _Rationale:_ it is a reference for explicit frame ownership and flat
  commands, while the user requires the package and audio core to be Pudu-native. _Rejected:_ foreign
  bindings.
- **Q:** Call the first framebuffer a full desktop toolkit? **A:** No. _Rationale:_ layout, text,
  accessibility, input, windows, and device audio remain named slices. _Rejected:_ a readiness claim
  broader than the implementation.
- **Q:** Optimize before exact output exists? **A:** No. _Rationale:_ pixel conformance is the oracle
  against which later batching and damage-region optimizations are checked. _Rejected:_ speed without
  a stable result.
- **Q:** Does avoiding foreign UI integration forbid calling the operating system? **A:** No.
  _Rationale:_ a real window must connect to a window server. _Accepted:_ a private target adapter
  whose pointers and framework types never cross the Pudu boundary. _Rejected:_ raylib, SDL,
  SwiftUI, AppKit-shaped public APIs, and program-authored foreign declarations.

## Referenced by

[[handoffs/_MOC]] · [[First Release Readiness]] · [[Native Application UI]] · [[Std Ui Canvas]]
