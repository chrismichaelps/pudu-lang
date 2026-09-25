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
- Persistent device-stream slice — `Std.Audio.Device` now opens an evaluation-owned persistent
  stream with the adapter-accepted format, bounded writes with explicit partial acceptance,
  pause/resume/volume, drain-or-immediate close, and snapshots carrying submitted media, a
  content-bounded hardware queue clock, state, underruns, interruptions, device changes, and timeline
  failures. The private macOS adapter preallocates two to eight buffers and keeps its callback to
  bounded atomic bookkeeping; the runtime serializes each token independently and tears abandoned
  streams down. `LaunchAudioStream.pudu` twice opened real hardware, fed 4,096 frames, exercised
  controls and stale-token refusal, and returned a positive hardware position. The configured Studio
  launch submitted all 16,016 frames, presented 27 of 30 pictures against the audio clock by dropping
  late pictures, recorded zero underruns/interruptions/device changes, wrote WAV and version-three
  JSON artifacts, and closed its real 480×270 window and queue.
- Qualified-pattern repair — the corrected audio fixture exposed that a misspelled dotted
  constructor was silently accepted. Pattern typing no longer falls from an exact qualified value or
  known type owner into the global bare-variant table. A missing module constructor is one `E3033`, a
  missing type-owned variant is one `E3034`, and named-field recovery avoids cascades. Isolated and
  loaded-`Std.Audio` regressions preserve the distinction.
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
- Playback cancellation — device play runs on a worker thread behind an atomic cancel token; Ctrl-C
  during an 8-second clip now stops the program in 0.07 s (exit 130) instead of after the clip, and a
  program watching for stop receives `Cancelled`.
- Input-bound sweep — every standard reader of outside text was probed with deeply nested and
  adversarial input. `7129952` bounds YAML block nesting; `39ce2b1` replaces the backtracking glob
  matcher with one walk (a pattern that ran over a minute answers in 11 ms) and, found by a
  980-pair differential run against the earlier matcher, corrects `**/` silently dropping its
  separator; the Regex slice bounds group nesting at 256. `Std.Text.Parse` repetition, `Std.Http`
  framing lengths, and regex searches were already bounded. `Std.Yaml`, `Std.Glob`, and `Std.Regex`
  gained missing mirrors.
- Lifecycle and interrupt sweep — `4e84ac8` caps the layout nesting budget at 512 so a caller-chosen
  budget cannot let a deep view stop the program; `995de2c` pumps desktop events in 16 ms native
  slices, so Ctrl-C during a 10-second pump exits 130 at 1.57 s instead of running on and exiting 0;
  `fab7bf7` routes every runtime catch of a host call through `Pudu.Eval.Io.trySynchronous`, so an
  interrupt reaching a program blocked in `Net.accept` exits 130 within 80 ms (ten of ten runs)
  instead of answering `user interrupt`. Studio still acknowledges 16,016 device frames and presents
  30 pictures after both changes.
- Deep value traversal — HTML rendering, compact and pretty JSON encoding, UI change discovery, and
  immutable UI patch application use explicit work state instead of evaluator recursion. A new
  fixture crosses the former failure boundary with 1,600-level program-built values and holds 15
  exact output, path, post-patch, and invalid-path claims. Replacing repeated indentation concatenation with the
  bounded native string repeat reduced its 5.1 MB pretty output run from about 30 seconds to about
  6 seconds; the unrestricted full suite passes.
- Project bootstrap — `pudu init` preserves existing regular files and stages missing content under
  an atomically acquired serialized lock, with competing creators receiving a typed refusal and the
  manifest committed last. Package identities follow the documented
  lowercase ASCII grammar. A generated application contains only Pudu and begins as the acyclic
  graph `Main -> App.Greeting -> Domain.Greeting`; seven filesystem properties and the now-mandatory
  scaffold gate cover refusals plus check/run/test/format/build/bundle behavior outside the checkout.
  The text audit retains `Std.Text.Builder`, shared `Str` remainders, and `Std.Text.Source` rather
  than adding an alias-only `StringBuilder` or an unmeasured view with ambiguous coordinates.
- Audit findings left open, each a named gap rather than a silent one: the accept-interrupt run
  that once stayed alive past 3 s is closed as not reproduced — a program printing readiness and then
  blocked in `Net.accept` stopped on SIGINT within 15 ms in 40 of 40 runs on 2026-09-14, twenty
  signalled as the call began and twenty 50 ms into it, after ten earlier readiness-gated runs; the
  original run was signalled at a fixed delay right after a rebuild, which measured startup; `Pudu.Foreign.Ownership` teardown cleanup still catches every exception;
  `Std.Toml.Read` still reads characters by
  position; no per-character appender from the earlier audit remains open.
- First-release sweep, 2026-09-14 — all ten gates pass after each slice. A qualified record type
  pattern (`Audio.Format { .. }`) wrongly drew `E3033` from the qualified-constructor check and is
  accepted again; `Std.Diff.unifiedDiff` reported a final-newline-only change as no change and now
  emits `\ No newline at end of file`; `Std.Url` and `Std.Http` form fields escaped scalar values
  instead of UTF-8 bytes (`€` became `%20%AC`) and now walk bytes through constant tables; and
  `charAt`, `length`, and `slice` read long text through a two-entry position cursor, so positional
  scans are linear (640,000 characters: 11.0 s to 0.94 s at -O2). Foreign teardown held no
  interrupt: every cleanup still runs, and an asynchronous exception is re-raised after the rest
  release. CI's standard-library compile step searched a nonexistent root `lib` and compiled only
  the examples; it now names `packages/pudu/v0.1/lib` (201 modules clean). `Std.Mime.negotiate`
  reordered offers of equal quality through a swapping sort and now keeps the client's order, with
  constant extension maps; `Std.Log` reads `show` escapes back in one pass. `Std.Toml.Read` took
  43.2 s for a 5,000-key table because each key rebuilt its path and searched its siblings; drafts
  addressed by position read it in 0.87 s, and writing a key through a value is now refused.
- Non-macOS build — CI runs on Linux, where the macOS media adapters are not compiled. The desktop,
  audio-stream, and audio-device runtimes kept store fields, helpers, and imports used only by the
  adapter branch, which fail a Linux build with warnings as errors; no local gate compiles that
  configuration. Without an adapter each store is now an empty constructor and adapter-only code
  sits inside the platform guard. Verified from macOS by removing the darwin `cpp-options` in a
  scratch worktree and type-checking all 181 library modules with `-fno-code -Werror`. Windows and
  Linux media adapters themselves remain unimplemented; those targets answer `UnsupportedPlatform`.
- Source archive — `cabal sdist pudu` declares every C source and header, including the audio-stream
  adapter. Unpacked outside the checkout it builds `pudu` with its own project file; with
  `pudu_datadir` pointing at the unpacked tree, that binary ran `UsesToml` from an unrelated
  directory and all 49 claims held. Without an install or `PUDU_LIB` an uninstalled build finds no
  library, which is expected, but its `E2014` help had read `looked in ` with nothing after it:
  the help was built from existing library locations only. With no library it now names
  `PUDU_LIB`, the installed layout, the package data directory, and the walk up from the executable
  in one phrase; with a library present it still names the roots searched.
- Open-issue sweep, 2026-09-14 — #218 (too few arguments passed the checker) reproduces as fixed:
  `add(1)` is `E3003` at the check and a defaulted parameter is still omitted directly and through a
  function value, guarded by `FunctionGenericSpec` (PR #221). #219 (wrapped parameter list moved to
  column zero) reproduces as fixed and is guarded by `FormatSpec` (PR #222). Both remain open on
  GitHub because their commits say `refs`, not `fixes`. The other open issues and the remaining
  readiness rows — package lock/fetch/update/publish, lexically owned workers with cancellation,
  HTTP cancellation and pooling, residency-bounded large-input fixtures, and Windows/Linux media
  adapters — are feature programs rather than defects.
- Large-input evidence scope — `Std.Csv` exposes only whole-text `parse`, `parseWith`, and
  `parseTable`, and `Std.Json` only whole-text `decode`; neither has a reader- or path-based entry.
  The readiness row's CSV and JSON residency fixtures therefore cannot exist until incremental readers
  do, and a buffered wrapper is explicitly not evidence. File streaming (`Std.Io.foldLines`,
  `foldChunks`) is the measurable base. Measured at -O2 through a process's peak resident memory:
  `foldLines` 87 MB at 10 MB and 86 MB at 100 MB, `countBytes` 82 and 82 MB, buffered
  `readAllLinesOf` 119 and 527 MB. `test/residency.py` makes that a gate at 2 and 20 MB. `foldLines`
  reads about 7.7 MB/s against `countBytes` at about 1 GB/s, so line splitting, not memory, is its
  remaining cost.
- CI gates `test/gates.sh` does not run — `api-lifecycle.py check`, the library compile step,
  `signal-drain`, `build-bundle`, `foreign-third-party`, `bench/request`, and both refusing
  `pudu doc` invocations — all pass locally against the optimized binary (2026-09-14).

## Exact next action

Continue the native media roadmap with the first Pudu **space** application loop over [[Std Ui Desktop]] and
[[Std Ui Screen]], translating native pointer/key/text/close events into screen inputs. Keep every
exact fixture as the semantic oracle. In parallel with that UI contract, add audio device
discovery/selection and active route-change recovery, then Windows and Linux target adapters; add
percentile latency/memory and hour-scale A/V drift gates before claiming interactive or real-time
performance.

## 2026-09-13 native lint transition

Role moved **Design → Construction → Validation** for [[Pudu Lint]] and [[Pudu CLI Lint]]. Public HLint
documentation is a behavioral reference only: Pudu keeps stable named findings, suppression, and
structured output, but fixes remain in the same typed compiler process and require exact source-span
proof. The construction slice owns the two lint modules, their two focused specs, CLI registration,
build/test registration, a live command gate, and matching vault pages. No review agent is used.
Validation passes eight CLI properties, four analyzer properties including a 3,001-visit structural
linearity oracle, the unrestricted full compiler suite, a warning-as-error build, both Cabal package
checks, the diagnostic identity registry, the Pudu-only generated-project workflow, and live JSON,
four-finding, fix, recompile, and clean-lint execution. Active ownership returns to **Stdlib
Implementer** for the persistent native media stream named above.

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
  platform-framework-shaped public APIs, and program-authored foreign declarations.

## Referenced by

[[handoffs/_MOC]] · [[First Release Readiness]] · [[Native Application UI]] · [[Std Ui Canvas]]
