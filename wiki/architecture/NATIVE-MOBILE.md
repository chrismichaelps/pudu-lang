---
type: architecture
status: ACTIVE_DESIGN
tags: [architecture, native, mobile, ios, android, ui, fui]
aliases: [Pudu Native]
---

# Pudu Native

## Purpose

Ship phone and tablet applications for iOS and Android written entirely in Pudu, presented with
real platform controls, compiled through the C11 backend, and built from Pudu configuration with
generated platform projects. Performance is a release gate measured against hand-written platform
applications on named devices, never a slogan.

This page records what the current toolchain can and cannot carry, the boundaries every later
slice must respect, and the order of work. It extends [[Native Application UI]] and
[[Native Emission Coverage]]; it does not replace them. The iOS feature target is [[Pudu Native iOS UI]].

## Feasibility against the current toolchain

| Requirement | Today | Gap to close first |
| --- | --- | --- |
| Compile a whole application to native code | C11 emitter covers an admitted subset; refusals are diagnostics, no fallback | Coverage of every construct an application uses, including host services and concurrency, which are still Pending |
| Link into a platform host | `pudu build --native --target <ios target>` emits a static archive and `pudu_program.h`; the host's own `main` calls `pudu_program_run` ([[Backend Emit Entry]], [[Backend Toolchain Library]]) | Exported Pudu functions callable from the host ([[Native Calls Delivery]]); one admitted start per process landed (#899) |
| Build for devices | `ios-arm64` and `ios-simulator-arm64` build with the selected Xcode SDK; Android names are reserved and report E6007/E6008 ([[Backend Native Target]]) | Android builds once an NDK is available; device and simulator slices packaged together inside generated projects |
| Call platform code | Foreign C calls are emitted through a runtime loader; on Apple targets library paths are admitted only from system locations, `@rpath`, or `@executable_path` | Calls from C back into Pudu for events and callbacks (#899) |
| Run on more than one thread | Runtime has no atomics or locks; reference counts are plain; process-level runtime parts (child programs, signals, exit, TLS, desktop, audio) are refused on mobile targets | A declared thread model for calls into Pudu (#899), and atomic counts only for values the type system marks as shared |
| Reload while developing | `pudu run --watch` restarts the program | State-preserving reload on simulators and emulators |
| Platform controls | Desktop presenter draws Pudu pixels; platform UI toolkits are excluded | The adapter boundary below |

Toolchain currency (the Xcode floor, the tested version, store rules and the SDK each capability
needs) is kept in one ledger and adopted per platform release; see [[Native Platform Adoption]].

## Decisions

### One compiled program, not two code generators

Application logic and the runtime are both Pudu, and both reach the device through the C11
backend. There is no second native backend for "application code". The reconciler, layout,
and event dispatch are written in Pudu and emitted as C11 like everything else, so they inherit
ownership checking and the same conformance fixtures. Hand-written C is limited to the host shim
that the platform requires and is kept below a fixed size budget.

### Platform controls through a language-owned adapter

[[Native Application UI]] excludes binding platform UI toolkits. Phones and tablets need platform
controls for text input, selection, scrolling physics, accessibility, and system appearance, so
this page adopts the same boundary already accepted for desktop windows: a private,
language-owned adapter may create and update platform controls, but no platform type, callback,
selector, or memory rule crosses into Pudu. Pudu sees typed values and typed failures only. A
control the adapter cannot realize answers `UnsupportedPlatform`; a silent no-op is forbidden.

### Mutation batches, not per-property calls

The reconciler diffs immutable view trees with structural sharing and produces one ordered batch
of create, update, insert, remove, and delete instructions per commit, encoded as a flat byte
buffer. The adapter applies a batch in one crossing. On Android this keeps the managed-runtime
boundary to one crossing per frame instead of one per property. Layout-only containers are
flattened away before the batch is built so the platform tree stays shallow.

### Threading

The first thread model is one: build, diff, layout, and mount run on the platform's main thread.
Compiled code makes this affordable, and it removes cross-thread ordering bugs from the first
release. Background work happens in structured tasks that hand results to the main thread as
input. Immutable trees keep a later move of diffing off the main thread possible without changing
the public model.

### Layout units and text

Mobile layout uses fractional points with explicit pixel snapping per display scale, not the
integer logical pixels of the desktop canvas. Text that platform controls render is measured by the
platform, cached by content, style, and width, and invalidated on system text-size changes.
Layout is Pudu's own flexible stack model from [[Std Ui Layout]], not a constraint solver.

### Lists and animation

Long lists map to the platform's recycling list view; Pudu supplies row models and stable identity,
the platform owns cell reuse and scrolling. Animations described with Std.Ui.Motion run on the
platform's animation engine and update properties directly; an animation frame never triggers a
commit, a diff, or a layout pass unless it changes layout. iOS scrolling and animations follow
the variable-refresh and device evidence contract in [[Pudu Native iOS UI#ProMotion and frame pacing]].

### Development reload

Application state already lives in one model value. Reload preserves that value: on simulators and
emulators a changed module is rebuilt as a shared library and swapped while the host keeps running;
when the model type changed, reload falls back to a restart with a typed migration or a fresh
model. Devices that forbid loading new code use a fast rebuild and model restore.

### Over-the-air updates

Compiled logic cannot be replaced over the air on iOS. Remote updates are limited to assets,
content, and configuration whose schema the installed binary already understands, signed and
tied to a fingerprint of the binary's native inputs, with rollback to the embedded copy. Logic
changes ship through the stores.

### Generated platform projects

Platform projects are build output. A typed, declarative patch set produced from Pudu
configuration generates them; every patch is idempotent and ordered by declared dependency, and
two patches writing the same key is a build error. A fingerprint over every native input decides
whether an existing development host can load a project or a rebuild is required. The first step builds the application bundle directly; generated projects and typed configuration patches build on it.

### Calling Swift and Kotlin

A module declares its interface once in Pudu. The toolchain generates the C header, a Swift
wrapper, and a Kotlin wrapper with its managed-runtime bridge, and checks the platform
implementation against that interface at build time. Conversions are generated, not looked up at
run time.

## View stream (#909, #912)

One stream carries each commit. It is a sequence of little-endian 32-bit words, applied in order by the host. Every instruction begins with its code word.

| Code | Instruction | Words that follow |
| --- | --- | --- |
| 1 | CREATE | node, kind (1 label, 2 button, 3 column, 4 row, 5 field, 6 toggle, 7 scroll, 8 list, 9 material, 10 progress, 11 activity, 12 slider, 13 stepper, 14 segments, 15 wheel, 16 date, 17 text area, 18 search, 19 symbol, 20 pages, 21 well, 22 image) |
| 2 | TEXT | node, byte length, then that many UTF-8 bytes |
| 3 | APPEND | column or row node, child node |
| 4 | ROOT | node shown as the screen's content |
| 5 | TAG | node, the tag its events report |
| 6 | RESET | none (forget every node) |
| 7 | STATE | node, 0 or 1 (a toggle's state) |
| 8 | HINT | node, byte length, UTF-8 bytes (a field's placeholder) |
| 9 | NAME | node, byte length, UTF-8 bytes (accessible name) |
| 10 | INSERT | parent, child, index |
| 11 | REMOVE | node, count, then count ids of its subtree (all forgotten) |
| 12 | MOVE | parent, child, index |
| 20 | THEME | count (7), then a kind, light word and dark word per role |
| 21 | APPEARANCE | code (0 unspecified, 1 light, 2 dark) |
| 22 | STYLE | node, text style code |
| 23 | COLOR | node, role code |
| 24 | RANGE | list node, total item count, first window index |
| 25 | COLUMNS | list node, column count |
| 26 | SURFACE | node, material code |
| 27 | GESTURES | node, tag, recognizer mask |
| 28 | ALERT | tag, style code, title text, message text, choice list |
| 29 | VALUE | node, value word (permille for progress, signed number, option index, or RGBA for a color well) |
| 30 | HAPTIC | haptic code |
| 31 | TRAITS | node, trait mask |
| 32 | ACCESS_HINT | node, text |
| 33 | ACCESS_VALUE | node, text |
| 34 | MENU | node, tag, choice list |
| 35 | ANIMATE | group, 0 or 1 |
| 36 | NAVIGATE | route count, then per route an id, a body node and a title; a sheet flag, then the sheet's id and body node when the flag is 1 |
| 37 | REFRESH | node, tag, 0 or 1 |
| 38 | FETCH | generation, method text, URL text, header count, a name and value text per header, body text |
| 39 | CANCEL | generation |
| 40 | WAKE | delay in milliseconds |
| 41 | BOUNDS | node, low, high, step (signed words) |
| 42 | OPTIONS | node, count, then each label as length-prefixed UTF-8 |
| 43 | COUNT | node, page count |
| 44 | MOMENT | node, mode (0 day, 1 time, 2 day and time), seconds high word, seconds low word |
| 45 | SOURCE | node, origin (0 asset name, 1 URL), scaling (0 fill, 1 fit, 2 stretch), then length-prefixed location text |
| 46 | OPEN | tag, then the URL as length-prefixed text |
| 47 | SHARE | tag, then the text as length-prefixed text |
| 48 | COPY | the text as length-prefixed text |
| 49 | PASTE | tag |
| 50 | STATUS | style (0 automatic, 1 light text, 2 dark text), hidden flag (0 or 1) |
| 51 | PERMISSIONS | count, then each kind code; answers with no prompt |
| 52 | PERMISSION | kind code; asks the person when not asked |
| 53 | SETTINGS | none; opens the application's page in settings |
| 54 | TABS | tab count; per tab its id, title, symbol and page count; per page its route id, body node and title; selected tab id; sheet flag, then the sheet's id and body node when the flag is 1 |

Events return through `pudu_ui_wait` as one 64-bit value: the kind in the high 32 bits, with the tag in the low 32 bits.

| Kind | Event | Payload |
| --- | --- | --- |
| 1 | tapped | tag |
| 2 | stopped | none |
| 3 | changed | tag; the text is read through `pudu_ui_event_text` |
| 4 | switched on | tag |
| 5 | switched off | tag |
| 8 | reached | tag; the first visible index is read through the detail call |
| 9 | gestured | tag, phase and signed values |
| 10 | chose | alert tag; the index of the choice taken |
| 11 | resized | scene size, as signed words |
| 12 | lifecycle | tag; the phase code |
| 13 | picked | menu tag; the index of the item |
| 14 | popped | tag (the route on top); detail (the surviving route) |
| 15 | dismissed | sheet tag |
| 16 | refreshed | tag |
| 17 | insets | four signed words: top, left, bottom, right |
| 18 | fetched | generation as tag; status as detail; body text; Retry-After word (-1 when absent) |
| 19 | woke | none |
| 20 | memory | none |
| 21 | valued | tag; signed value or index as detail |
| 22 | colored | tag; RGBA as detail |
| 23 | dated | tag; seconds high word, then low word |
| 24 | imaged | tag; detail 1 when shown, 0 when it could not be |
| 25 | opened | tag; detail 1 when the platform opened the URL, 0 when not |
| 26 | shared | tag; detail 1 when shared (Android: chooser opened), 0 when the sheet closed |
| 27 | pasted | tag; the clipboard text, empty when none |
| 28 | permissioned | tag is the kind code; detail is the state code (0 not asked to 6 unavailable) |
| 29 | selected | tab id; no detail |
| 30 | linked | URL text; no detail |

Codes 10 to 12 only add instructions, so a stream of codes 1 to 9 means the same. The view module no longer writes RESET; the host keeps it so a stream from an earlier writer still means the same. Nodes carry stable ids handed out by the program and recycled after REMOVE (#914). Compiled views extend the stream further under ADR-0031 (compiled native execution).

Codes 26 to 44 and events 9 to 23 are one numbering shared by the iOS and Android hosts. Android's BOUNDS, OPTIONS, COUNT and MOMENT moved from 36 to 39 to 41 to 44, and its VALUED, COLORED and DATED moved from 14 to 16 to 21 to 23, because 36 to 40 and 14 to 20 are already NAVIGATE to WAKE and POPPED to MEMORY. Both hosts handle every instruction 1 to 50 and report every event 1 to 27. Android realizes navigation with a platform toolbar and dialogs, refresh with an overlay indicator, requests through the platform HTTP client and response cache, and requests the INTERNET permission. Android runtime behavior is not yet exercised on a device or emulator.

## FUI on native

FUI renders HTML today and its tokens carry CSS units. Native support requires:

- A renderer-neutral component tree, produced by FUI and consumed by the HTML, desktop, and
  native presenters.
- Typed token values (lengths, colors, durations, type scales) resolved per platform, replacing
  CSS strings.
- Touch-first replacements for hover-only components (hover card, tooltip).
- Platform-adaptive components whose idiom changes by platform and device class while the
  application code stays the same.

| FUI component | iOS realization | Android realization | Note |
| --- | --- | --- | --- |
| Button, Toggle, Slider, Progress, Input, Textarea | platform control | platform control | direct |
| Checkbox, RadioGroup | list row with checkmark | platform control | idiom differs |
| Tabs | segmented control in content; tab bar at app level | tab row; bottom navigation at app level | split into two components |
| NativeSelect | menu or picker | dropdown menu | |
| Alert, Dialog | alert or sheet | dialog or bottom sheet | |
| Popover | popover on tablet, sheet on phone | menu or popup | device-class adaptive |
| Collapsible | disclosure group | expandable row | |
| ScrollArea, Table | scroll view, recycling list | scroll container, recycling list | lists must recycle |
| Card, Avatar, Badge, Skeleton | composed from primitives | composed from primitives | no platform control needed |
| HoverCard, Tooltip | long press preview | long press tooltip | redesign for touch |

New components required for real applications: navigation stack, tab bar, sidebar and navigation
rail for tablets, sheet with detents, action sheet, context menu, swipe actions, pull to refresh,
search field, date and time pickers, stepper, segmented control, page indicator, toast or
snackbar, and a floating action button with an iOS fallback.

FUI's native presenter targets [[Std Mobile View]]: a renderer-neutral FUI tree is realized as these controls on phones, and as HTML on the web.

## Phase gates

| Phase | Exit evidence |
| --- | --- |
| 0 Toolchain | Library output and iOS device and simulator targets with a simulator smoke run (#878, done); the entry guard (#899, done); C-to-Pudu calls ([[Native Calls Delivery]]); direct calls (#904) and export crossings for text, records and Result (#906) |
| 1 First light | A counter application built from Pudu alone runs on an iOS simulator, and later an Android emulator, with platform label and button, measured cold start and binary size recorded |
| 2 Declarative UI | Reconciler, mutation batches, recycling list, navigation stack, accessibility labels reaching the platform tree, simulator reload |
| 3 Tooling | Generated projects, patch set, fingerprinted development host, signed store artifacts from local builds; `pudu build --app` writes a signed simulator application (#916) |
| 4 Hardening | Percentile frame times on list scroll, input latency, cold start, resident memory, and size compared against hand-written platform baselines on named mid-range and high-end phones and tablets |
| 5 Ecosystem | Versioned modules, compatibility guarantees, migration tooling |

Every performance claim needs percentile frame deadlines, cold-start time to first interactive
frame, peak resident memory, and binary size on named devices, in line with
[[Desktop Capability Conformance]].

## Grill Log

- **Q:** Emit only the runtime as C11 and compile application code another way? **A:** No.
  _Rationale:_ the C11 backend is the only native code path; a second one doubles conformance
  work. _Rejected:_ a split pipeline.
- **Q:** Draw every pixel in Pudu as the desktop presenter does? **A:** No for mobile.
  _Rationale:_ text input, accessibility, scrolling physics, and system appearance are expected to
  be the platform's own. _Rejected:_ a custom-drawn control set as the default.
- **Q:** Let platform types appear in the Pudu API? **A:** No. _Rationale:_ the adapter boundary
  keeps ownership and failure in Pudu terms. _Rejected:_ a platform class hierarchy facade.
- **Q:** Concurrent reconciliation from the first release? **A:** No. _Rationale:_ the runtime is
  single-threaded today and compiled diffing is cheap. _Rejected:_ shared mutable trees across
  threads before a thread model exists.
- **Q:** Promise over-the-air logic updates? **A:** No. _Rationale:_ compiled code cannot be
  replaced remotely under iOS store rules. _Rejected:_ shipping an interpreter to enable it.
- **Q:** Promise performance equal to platform applications? **A:** Only as a measured gate.
  _Rationale:_ claims need device evidence. _Rejected:_ unmeasured parity claims.

## Referenced by

[[architecture/_MOC]] · [[Native Application UI]] · [[Native Emission Coverage]] · [[Native Mobile Targets]] · [[Pudu Native iOS UI]]

## Application assets (#973)

An application's `assets` directory, beside its entry module, is packaged under the same relative names on every platform. A program names an asset as a relative path such as `icons/a-1.png`. Names are restricted to ASCII letters, digits, dots, dashes and underscores, with no hidden segment; a link is refused. A refusal is E6013 ([[Pudu Diagnostic Native]]). iOS copies assets into the bundle's `assets` directory; Android passes them to aapt2 with `-A`.

## System requests (#974)

OPEN 46, SHARE 47, COPY 48, PASTE 49 and STATUS 50 are requests with one reported answer each, except COPY and STATUS, which report nothing. Their answers are OPENED 25, SHARED 26 and PASTED 27. The iOS host presents the share sheet and reports its completion ([[pudu-ios-system]]). The Android host starts an `ACTION_SEND` chooser and reports SHARED once it is shown, because the chooser does not report the outcome ([[PuduSystem]]). Status bar style is applied by the scene on iOS ([[pudu-ios-scene]]) and through `WindowInsetsController` on Android.

## Remote bodies and timeouts (#974)

Remote images are capped at 32 MB on both hosts; iOS stops the transfer while it downloads. Android fetch requests read at most 16 MB of body. Connections time out after 15 seconds to connect and 30 seconds to read on Android. iOS image requests time out after 30 seconds without data and 60 seconds for the whole resource.

## Tabs (#977)

TABS 54 shows a tab bar: one stack per tab, each tab's bar item title and system symbol, and at most one page sheet over the bar. A person's pick is reported as SELECTED 29 with the tab id; a pop inside a tab is reported as POPPED 14. TABS and NAVIGATE replace each other. The iOS host is [[pudu-ios-tabs]]. The Android host is [[PuduTabs]], fed by [[pudu-android-routes]], and shows titles only because Android has no system symbol set. The model is [[Std Mobile Navigation]]; the example is [[Tabs Example]].

## Application identity and links (#978)

The program's `pudu.toml` names the application under `[app]`: name, identifier, version, build and schemes. [[Pudu Backend Identity]] checks each value before a build, and E6018 refuses a value a store or platform would reject. The identity reaches Info.plist (display name, version, build, URL types) and the Android manifest (package, version code and name, label, one VIEW filter per scheme, singleTask launch). A link that opens the application arrives as LINKED 30 with the URL text, at launch and while it runs. The example is [[Links Example]]; the open handoff is [[Native App Identity]].

## Permissions (#976)

A program declares each permission it may request under `[app.permissions]` in its manifest, with the reason the person reads. The build refuses a request for an undeclared kind (E6014), a key no kind has (E6015) and an empty reason (E6016), and warns for a declaration never requested (W6017). Each declared kind writes its iOS usage keys, compile flag and framework, and its Android manifest entries.

The state model is one closed set across platforms: NotAsked, Granted, Limited (partial access), Provisional (quiet notifications), Denied (may ask again), Blocked (only Settings can allow) and Unavailable. The program requests with PERMISSION 52, checks with PERMISSIONS 51 and opens Settings with SETTINGS 53. Answers arrive as PERMISSIONED 28. See [[Std Mobile Permission]], [[pudu-ios-permission]] and [[PuduPermission]].
