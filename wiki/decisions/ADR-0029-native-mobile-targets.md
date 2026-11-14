---
type: decision
status: ACCEPTED
date: 2026-11-13
tags: [decision, native, backend, toolchain, mobile]
aliases: [Native Mobile Targets]
---
# ADR-0029 — Native mobile targets build a library a host application enters

## Context

`pudu build --native` writes one C11 translation unit and links it into an
executable whose C `main` runs the program. A mobile operating system does not
start a program that way: the application owns `main` and its run loop, and a
Pudu program has to run inside it. The application platform also forbids
some things a desktop program may do (start other programs, quit itself,
load code from an arbitrary path), and the packaged macOS host sources do not
exist there. An application framework written in Pudu therefore needs a
native build whose product the platform's own project links, entered by a
call rather than by process start.

## Decision

### Target names

`pudu build <file> --native --target <name>` selects a mobile target. The
names are closed and listed by the compiler:

| Name | Platform | Status |
| --- | --- | --- |
| `ios-arm64` | iOS devices, SDK `iphoneos`, `arm64-apple-ios15.0` | built |
| `ios-simulator-arm64` | the iOS simulator on Apple silicon, SDK `iphonesimulator`, `arm64-apple-ios15.0-simulator` | built |
| `android-arm64` | Android, ABI `arm64-v8a` | reserved |
| `android-x86_64` | the Android emulator, ABI `x86_64` | reserved |

Without `--target`, `--native` keeps building a host executable exactly as
before. `--target` without `--native` keeps naming a prebuilt runtime pack
([[Deployment Targets]]); each form lists its own names when given an unknown
one. iOS 15.0 is the minimum: it carries every C11 library facility the
runtime parts use, and it is the oldest release current Xcode still deploys
to without warnings.

### iOS output

A mobile build writes a static library (`-o`, default `lib<stem>.a`) and,
beside it, `pudu_program.h`, which declares the one entry:

```c
int pudu_program_run(int count, char **values);
```

The call runs the program's `main` on the calling thread and returns its exit
status after both standard streams are flushed and every foreign claim is
released. The generated translation unit keeps its own entry body in a
`static` function, so the desktop and mobile units differ only in how they are
entered. The header has a fixed name because the entry symbol is fixed: one
Pudu program per application, and the host's include line never changes when
the program is renamed. When the program needs a system library the host must
link (the compression library), the header and the build's report name it.

There is no separate teardown export. The run already releases what it owns
before returning; a teardown function would have nothing to do.

A failure the program reports still ends the process with status 1 after its
diagnostic, as on the desktop. Returning a failure to the host instead of
ending it needs unwinding the runtime does not have yet. The run is entered
once per process: module state is not reset between runs.

### Why not an XCFramework

An XCFramework bundles the device and simulator slices, which are two builds
of one program. One `--target` builds one slice; the host combines both with
`xcodebuild -create-xcframework -library <device>.a -headers <dir> -library
<simulator>.a -headers <dir> -output Program.xcframework`. Producing the
framework inside the compiler would make one build run two toolchains and
choose a layout Xcode already owns.

### Toolchain discovery

An Apple target uses the platform SDK through `xcrun` (`PUDU_XCRUN` when set,
otherwise `xcrun` on `PATH`): `xcrun --sdk <sdk> --show-sdk-path` gives the
system root, and `xcrun --sdk <sdk> --find clang` and `--find libtool` the
tools. The unit is compiled to an object with the desktop's fixed flags plus
`-target <triple> -isysroot <root>`, then archived with `libtool -static`.
The archive is published by rename, as the executable is. No `xcrun`, or an
SDK it does not know, is `E6007` naming the target and what was looked for.

An Android target looks for the NDK in `ANDROID_NDK_HOME`, then
`ANDROID_NDK_ROOT`. Neither naming a directory is `E6007`. A present NDK is
`E6008`: the Android output is designed (below) and not built.

### What a mobile target refuses

A program whose emitted runtime selects a part the target cannot carry is
refused with `E6008` before any compiler runs, naming the construct and why.
The refusal is never a C compile error.

| Runtime part | Construct | Why iOS refuses it |
| --- | --- | --- |
| `host_children` | child programs | the application sandbox forbids starting processes |
| `host_signals` | stop signals | the system suspends and ends applications without them |
| `host_exit` | ending the process | an application never quits itself |
| `host_tls` | TLS connections | the platform ships no OpenSSL |
| `host_desktop` | desktop windows | the adapter is AppKit, macOS only |
| `host_audio` | audio devices and streams | the adapter is the macOS one |

Android targets refuse the same parts until the Android slice measures what
an NDK application may do; only the reasons name the platform.

The packaged macOS host sources are never selected for a mobile target: their
parts are refused first.

### Foreign libraries

Native foreign calls resolve libraries at run time as the interpreter does
([[Native Foreign Call Sites]]). On iOS a library written as a bare name (`c`,
`z`, `sqlite3`) is a system library or the program itself, and is kept. A
library written as a path is kept only under `/System/Library/Frameworks/`,
`/usr/lib/`, `@rpath/` or `@executable_path/`, without parent traversal components: system frameworks and
frameworks embedded in the application bundle. Any other path is `E6008`,
because an application cannot load code from outside its signed bundle. On
Android every path is refused: libraries are packaged in the APK and named by
their leaf. A version is a filename fragment and may not contain a slash.

### Android design (not built)

The NDK's `clang` for `aarch64-linux-android24` or `x86_64-linux-android24`
builds a shared library (`lib<stem>.so`) per ABI exporting the same
`pudu_program_run` and header. The host loads it with `System.loadLibrary`
and calls the entry from JNI glue (#875 decides the thread model and #880 owns
the glue). Foreign libraries resolve from the APK's native library
directory.

## Rejected

- Emitting `main` and renaming it with a preprocessor define. _Rationale:_ the
  entry and its flush are part of the generated contract; a define would hide
  the embeddable form from the emitter's own tests.
- Producing an XCFramework from one build. _Rationale:_ see above.
- Refusing at the C compiler. _Rationale:_ a C error names the generated
  source, not the construct, and reads as a compiler defect.
- Locating a refusal at the construct. _Rationale:_ refusals are decided from
  the selected runtime parts, which carry no source span; the root module's
  span names the program and the message names the construct.

## Consequences

The emitter offers two entry forms; the toolchain gains an archive path beside
the executable path and shares its bounded process runner. Callbacks into Pudu
(#876), Objective-C (#879) and Swift (#881) build on the library this target
writes. The run's process-ending failures and single-run limit are recorded
obligations.

## Referenced by

[[decisions/_MOC]] · [[Native Emission Coverage]] · [[Deployment Targets]] ·
[[Backend Native Target]] · [[Native Mobile Targets Delivery]] · [[Pudu Native]]
