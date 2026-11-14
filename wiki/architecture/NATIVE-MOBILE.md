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
[[Native Emission Coverage]]; it does not replace them.

## Feasibility against the current toolchain

| Requirement | Today | Gap to close first |
| --- | --- | --- |
| Compile a whole application to native code | C11 emitter covers an admitted subset; refusals are diagnostics, no fallback | Coverage of every construct an application uses, including host services and concurrency, which are still Pending |
| Link into a platform host | `pudu build --native --target <ios target>` emits a static archive and `pudu_program.h`; the host's own `main` calls `pudu_program_run` ([[Backend Emit Entry]], [[Backend Toolchain Library]]) | Exported Pudu functions callable from the host, and one admitted start per process (#899) |
| Build for devices | `ios-arm64` and `ios-simulator-arm64` build with the selected Xcode SDK; Android names are reserved and report E6007/E6008 ([[Backend Native Target]]) | Android builds once an NDK is available; device and simulator slices packaged together inside generated projects |
| Call platform code | Foreign C calls are emitted through a runtime loader; on Apple targets library paths are admitted only from system locations, `@rpath`, or `@executable_path` | Calls from C back into Pudu for events and callbacks (#899) |
| Run on more than one thread | Runtime has no atomics or locks; reference counts are plain; process-level runtime parts (child programs, signals, exit, TLS, desktop, audio) are refused on mobile targets | A declared thread model for calls into Pudu (#899), and atomic counts only for values the type system marks as shared |
| Reload while developing | `pudu run --watch` restarts the program | State-preserving reload on simulators and emulators |
| Platform controls | Desktop presenter draws Pudu pixels; platform UI toolkits are excluded | The adapter boundary below |

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
commit, a diff, or a layout pass unless it changes layout.

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
whether an existing development host can load a project or a rebuild is required.

### Calling Swift and Kotlin

A module declares its interface once in Pudu. The toolchain generates the C header, a Swift
wrapper, and a Kotlin wrapper with its managed-runtime bridge, and checks the platform
implementation against that interface at build time. Conversions are generated, not looked up at
run time.

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

## Phase gates

| Phase | Exit evidence |
| --- | --- |
| 0 Toolchain | Library output and iOS device and simulator targets with a simulator smoke run (#878, done); C-to-Pudu calls and the entry guard (#899) |
| 1 First light | A counter application built from Pudu alone runs on an iOS simulator, and later an Android emulator, with platform label and button, measured cold start and binary size recorded |
| 2 Declarative UI | Reconciler, mutation batches, recycling list, navigation stack, accessibility labels reaching the platform tree, simulator reload |
| 3 Tooling | Generated projects, patch set, fingerprinted development host, signed store artifacts from local builds |
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

[[architecture/_MOC]] · [[Native Application UI]] · [[Native Emission Coverage]] · [[Native Mobile Targets]]
