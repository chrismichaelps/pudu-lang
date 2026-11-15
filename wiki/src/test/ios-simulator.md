---
type: module
path: "@root/test/ios-simulator.mjs"
fidelity: Active
tags: [module, test, native, mobile]
aliases: [iOS Simulator Run]
---

# iOS Simulator Run

## Purpose and interface

`node test/ios-simulator.mjs <pudu>` builds a Pudu program for
`ios-simulator-arm64`, links it into a minimal application and compares what
the application prints on a booted simulator with `pudu run`.

Use `--require-simulator` to make an unavailable simulator a failure.
[[iOS Simulator CI]] uses this mode.

## Algorithm and invariants

- Reports unavailable prerequisites outside Apple silicon macOS, when
  `xcrun` is missing, or when no iOS simulator runtime is installed. The
  default mode skips and required mode fails.
- The program calls `abs` and `strlen` through `foreign "c"` and calls
  `CFAbsoluteTimeGetCurrent` through the CoreFoundation system framework.
  It checks that the returned timestamp is positive, so the host and simulator
  can compare stable output.
- Compile a small C framework for the simulator with an `@rpath` install name,
  sign it inside the app's Frameworks directory, and resolve its symbol from
  Pudu without linking the host directly to the framework. Run the same C
  implementation through a macOS dylib to compare interpreter output.
- `main.m` owns `main`, calls `pudu_program_run` inside an autorelease pool,
  prints the status it returns and ends, so the launch finishes by itself.
- Each example is built with `pudu build --native --target ios-simulator-arm64 --app`
  ([[Backend Toolchain App]]), which compiles and links the application, writes its
  `Info.plist` and signs it. The script no longer compiles the host or writes the bundle
  itself.
- The script creates its own iPhone device, boots it, installs, launches with
  `--console-pty` capturing standard output, and deletes the device afterwards
  on every path. An explicit `PUDU_IOS_SIMULATOR_UDID` instead uses an already
  booted test simulator and uninstalls the apps it installed after each case.
  Private devices retain test apps until device deletion, so per-app
  uninstall is skipped there.
- Passes when the captured lines equal `pudu run`'s output followed by the
  status line.

## Dependencies and consumers

[[Native Mobile Targets]], [[Backend Toolchain Library]]. Run on an Apple silicon Mac with an installed iOS runtime.

## Resolved Grill Log

- **Q:** Uninstall each app on a private device? **A:** Device deletion already
  removes every app. Avoid an extra service call that can time out on a cold
  hosted runner. Explicitly reused devices still need per-app cleanup.

- **Q:** Why create a device rather than use an existing one? **A:** An
  existing device may be booted by its owner; a private device is deleted
  afterwards without touching anyone else's.
- **Q:** Why not start `UIApplicationMain`? **A:** The check is that the
  library runs inside an application process the host owns; a run loop would
  only make the launch wait. Where a host calls the entry is its framework's
  choice.

## Cold simulator timing (#899)

Hosted macOS runners failed intermittently with `spawnSync xcrun ETIMEDOUT`
while installing or first launching the app on a newly booted simulator, under
the two-minute default every tool call shared. Install and launch now wait up
to five minutes, a timeout names the command that expired, and a launch that
timed out or reported no `PUDU_SMOKE` line is terminated and tried once more.
The first simulator query, listing runtimes, gets the same five-minute allowance as installing and launching, because a cold simulator service on a hosted runner can take minutes to answer it (#909).

Resolved Grill Log:
- A device the script creates waits up to ten minutes for its first boot; a second family booting beside the phone is slower than the five-minute install and launch limit allows.
- Retry only the absence of a report; any line the app did
report is compared as is, so a wrong value can never pass on a second try.
_Rejected:_ retrying the whole smoke, which would also hide compile or
foreign-call regressions.

## Counter example (#909)

The script also builds and runs the counter example, `examples/mobile/Counter.pudu`, with the iOS host adapter ([[iOS Host Adapter]]). It runs the program with `PUDU_UI_SELFTEST=3` and expects `PUDU_LABEL Count: 3` and status 0. It also records `PUDU_FIRST_FRAME_MS` and the linked executable size in bytes.

The script also builds `examples/mobile/Form.pudu` ([[Native Form Example]]) and runs it twice with `PUDU_UI_TYPE=Ada`. With no taps, the label must read `Hello, Ada (subscribed)`. With one tap of every button (Clear), it must read `Hello, stranger`. Both runs must exit with status 0.

## Keyed list example (#914)

The script runs `examples/mobile/List.pudu` ([[Native List Example]]) with `PUDU_UI_TYPE=Milk`, then taps every button in three rounds, each round pressing Add and then Reverse. The labels must read, in screen order, `3 items`, `Milk 3`, `Milk 1`, `Milk 2`, and the run must exit with status 0.

Every app's labels are compared in screen order, so a reordered or missing row fails even when each label text is present.

## Themed example (#923)

The script runs `examples/mobile/Themed.pudu` ([[Native Themed Example]]) with `PUDU_UI_THEME_TEST` set. The run must print these lines, in order, and exit with status 0:

- `PUDU_THEME ink light #1F2A44FF dark #E8EEFFFF`: the ink label's text color resolved under the light and dark traits.
- `PUDU_THEME appearance dark`: the window's user-interface style override is dark.
- `PUDU_THEME type grows`: the Body style's font at the accessibility extra-large content size is larger than at the default size.

Resolved Grill Log: assert the resolved colors and the font size, not only that the program exits. A theme that is accepted but never painted would otherwise pass.

## List example (#925)

The script runs `examples/mobile/Catalog.pudu` ([[Native Catalog Example]]) with `PUDU_UI_LIST_TEST` set. The run must print these lines, in order, and exit with status 0:

- `PUDU_LIST reached Item 1000`: the self-test scrolled the first list to its last item, and that item's cell shows its label.
- `PUDU_LIST reused`: fewer cells were made than a fifth of the 1,000 items.
- `PUDU_CELLS <made> of <total> items`: a measurement of the cells made, printed for the record.

The label report must also list exactly the last 120 items, `Item 881` through `Item 1000`, in screen order. The window clamps at the end of the list, so the final window holds items 881 to 1000 and no others.

Resolved Grill Log: assert the reached label and the reuse count, not only the exit status. A list that never scrolls, or that builds every cell, would otherwise pass.

## Refused list instruction (#925)

The script's helper `refusedApp` runs a third case: a RANGE instruction, written directly with `Std.Mobile.Stream`, is applied to a label. The process must abort with `pudu: a view stream shaped a node that is not a list: 0`, and no first frame may be reported.

Resolved Grill Log: the refusal belongs to the host, which alone knows the node's kind; the Pudu stream is well formed, so only the simulator can reject it.

## Application output collision (#916)

Once per run, build a minimal Pudu program into an existing `.app` directory
containing a marker. Require `E6006` and verify the marker bytes survive. The
collision exercises bundle publication regardless of the view tree or device
family. Each Counter run separately builds, installs, and boots its app.

Resolved Grill Log: assert both the observable refusal and the preserved file. An
exit code alone could hide a build that damaged the old path before failing.

## Scrolling and keyboard (#919)

The feed reports its safe scroll viewport and all 40 labels in order. The host self-test focuses
the field below the initial viewport, waits for the keyboard guide to shrink the viewport,
verifies the field is visible, then dismisses the keyboard and checks the restored viewport. A generated app first sends an empty update, which must produce no first-frame report. It then sends APPEND to a label and must terminate with the existing stream defect diagnostic.

Resolved Grill Log: observe platform layout and the field frame. A generated focus event alone
cannot show whether the viewport actually resized.

## Refused stream checks (#923)

The script's helper `refusedApp(device, scratch, what, imports, body, refusal)` writes a
program, builds it with `--app`, launches it on the device, and requires the given host
refusal. It also requires that no first frame is reported and that the process does not exit
with a clean status. Two cases run through it:

- Invalid group placement: the message is unchanged from the #919 check.
- A text style on a group: `View.Styled(Theme.Body, View.Column([]))` is mounted and applied,
  and the process must abort with `pudu: a view stream styled a node that shows no text: 0`.

Resolved Grill Log: Q: Why test the refusal on a simulator rather than in the fixture? A: The
refusal belongs to the host; the Pudu stream for it is well formed, so only the host can reject
it.

## Glass material (#928)

The script runs `examples/mobile/Glass.pudu` ([[Native Glass Example]]) with `PUDU_UI_MATERIAL_TEST` set, on two runtimes:

- The newest installed runtime, iOS 26 or later. The run must print `PUDU_MATERIAL glass`, the label `Glass` in screen order, and exit with status 0.
- The first installed iOS runtime older than 26 (iOS 18.0 on the development Mac). The run must print `PUDU_MATERIAL blur`, the same label, and exit with status 0. The script creates a private iPhone device on that runtime and deletes it afterwards, as above. If no runtime older than 26 is installed, this run is skipped and the script says so.

Resolved Grill Log: assert the realization line on each runtime, not only the exit status. A glass branch that a pre-26 system also reached would otherwise pass the fallback run.

## Device matrix (#926)

After the iPhone runs, the script picks the newest available device type of every other family
the selected runtime supports, iPad and any new family, and runs Counter, Feed and Catalog on
each. The script fails if a family the runtime offers cannot boot a device of that family.
Each run uses a private device that is deleted afterwards, as above. A newly
created device gets ten minutes for its first boot.

Resolved Grill Log: one device per family, newest first, so a new emulator type is exercised as
soon as its runtime is installed. A family the runtime offers that fails to boot is a failure,
not a skip; a skip would hide the regression the matrix exists to catch. _Rejected:_ a fixed list
of device names, which would miss families the list does not name.

## Referenced by

[[Native Mobile Targets]] · [[Native Mobile Targets Delivery]] · [[Native Controls Delivery]] · [[Native Keyed Lists Delivery]] · [[Native iOS Theming Delivery]] · [[Native iOS Recycling Delivery]]

## Capability showcase (#930)

The Showcase, `examples/mobile/Showcase.pudu` ([[Native Showcase Example]]), is run with `PUDU_UI_CAPABILITY_TEST` set, and with `PUDU_UI_SELFTEST` also set so that the haptic line is printed. Its expected report lines are listed in [[Native Showcase Example]]. The self-test sequence is [[iOS Host Capability Test]].

Negative logic: this script does not yet compare the capability lines. The Showcase run is manual until the suite records them.
