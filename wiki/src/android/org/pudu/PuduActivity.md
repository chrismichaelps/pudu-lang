---
type: module
path: "@root/packages/pudu/v0.1/android/org/pudu/PuduActivity.java"
fidelity: Active
subsystem: "[[Backend]]"
tags: [module, native, android, activity]
aliases: [Native Android Activity]
---

# Native Android Activity

## Purpose and interface

The application's one activity, `org.pudu.PuduActivity`. It loads the program's
library `libpudu_app`, gives the host its surface, and reports the scene's size and
lifecycle to the program, as the iOS host does ([[iOS Host Adapter]]). It is the
launcher activity of the package built by [[Backend Toolchain Android]].

```java
public final class PuduActivity extends Activity
static final int RESIZED = 11, LIFECYCLE = 12;
static final int ACTIVE = 1, INACTIVE = 2, BACKGROUND = 3, FOREGROUND = 4;
static final int MAX_TAPS = 100;
```

## Algorithm and invariants

- `onCreate` loads `pudu_app`, installs a `FrameLayout` as the content view, and
  hands the activity, the surface, the display density and the night-mode flag to
  `PuduBridge.start`.
- Size reporting: on each layout change the width and height are converted to points
  by density. The size class per axis is 2 (regular) at 600 points or more in width
  and 500 points or more in height, else 1 (compact). The four values are sent as a
  `RESIZED` event, and only when they change. A zero width is not reported.
- Lifecycle: `onResume` sends `ACTIVE`, `onPause` sends `INACTIVE`, `onStop` sends
  `BACKGROUND`, and `onStart` after a stop sends `FOREGROUND`. Each is a `LIFECYCLE`
  event.
- Configuration changes forward the night-mode flag to `PuduBridge.configured`.
- Self-test extras, read from the launch intent:
  - `PUDU_UI_SELFTEST`: a tap count, parsed as an integer. A missing or malformed
    value is 0, and the count is capped at `MAX_TAPS` (100).
  - `PUDU_UI_TYPE`: text the self-test types.
  - `PUDU_UI_CONTROLS_TEST`: presence enables the controls self-test.
  - `PUDU_UI_CAPABILITY_TEST`: presence enables the capability self-test.
- The bridge receives the self-test values only when the activity decides testing is
  on (see the gate below). Otherwise the bridge receives an empty intent's values.

## Self-test gate

The gate is `testBuild()`. `PuduBridge.testing` is true only when the package is a
test build (debuggable and carrying the `org.pudu.selftest` marker) and the launch
intent carries `PUDU_UI_SELFTEST`. When it is
false, the activity replaces the launch intent with an empty one, so every extra is
dropped and the bridge runs without self-test behavior.

The launcher activity is exported, so any application can send these extras. The gate
therefore depends on the build, not on the caller. Only a test build
(`PUDU_ANDROID_TEST_BUILD` set) passes `--debug-mode` to `aapt2`, which marks the
package debuggable.

## Self-test gate (#951)

`testBuild()` answers true only when the package is debuggable and its
manifest carries `org.pudu.selftest`. Without both, the activity replaces the
launch intent with an empty one, so every extra is dropped.

Resolved Grill Log: check the build-time marker, not the debuggable flag
alone, since the activity is exported as the launcher.

Back to [[Backend Toolchain Android]].

## Links (#978)

- `onCreate` passes the launch intent to `linked`. `onNewIntent` stores the new intent and calls `linked` again; the activity is `singleTask`, so a later link arrives there rather than in a second activity.
- `linked` queues LINKED (30) with the intent's data URI as text, only for an `ACTION_VIEW` intent that carries data. Other intents are ignored.

The link path is not gated by the self-test marker: a released package also reports links.

## Negative Logic

- No self-test without a debuggable build. A released package ignores every
  self-test extra.
- No thread-local JNI state is kept here; the bridge owns the event dispatch.

## Dependencies and consumers

[[Backend Toolchain Android]] (packages the activity, its manifest and the bridge
classes), [[Native Toolchain Host Sources]] (the host translation unit the bridge
calls), [[Native Mobile Targets]].

## Resolved Grill Log

- **Q:** Why does the activity check the build's test marker before honoring extras?
  **A:** The launcher activity is exported, so a self-test switch that any application
  can send must not be honored in a released build. _Rejected:_ trusting the intent
  extras unconditionally.

## Referenced by

[[src/Pudu/Backend/Toolchain/Android]] · [[src/Pudu/Backend/_MOC]]

## Insets, memory and back (#971)

- Window insets: the surface listens for window insets and pads itself by the union of the system bars and the display cutout, so content stays clear of them under edge to edge. The insets are converted to dp by density and reported as one `INSETS` (17) event with the top, left, bottom and right values, only when they change.
- Memory: `onTrimMemory` reports `MEMORY` (20) when the level is running low, running critical, or moderate and above. `onLowMemory` reports `MEMORY` as well. The event carries no payload.
- Back: `onBackPressed` calls `PuduNavigator.back` first. The platform's own back runs only when the navigator has nothing to pop. See [[PuduNavigator]].

Resolved Grill Log: a memory event is sent for every trim level from running low upward, not only the critical level, so the program can release caches before the system has to kill the process.

## Services (#989)

- `onActivityResult` routes each result by request code to [[PuduAuth]] and [[PuduMedia]].
- A launch or new intent that carries `org.pudu.notified` is reported as NOTIFIED 35 for its id.
- The activity tells [[PuduMedia]] when it resumes, so BROWSED 37 is reported after the browser returns.
