---
type: module
path: "@root/packages/pudu/v0.1/android/org/pudu/PuduDevice.java"
fidelity: Active
subsystem: "[[Backend]]"
tags: [module, native, android, device, network]
aliases: [PuduDevice, Native Android Device]
---

# PuduDevice

## Purpose and interface

Device facts, network reachability and keep-awake on the Android host. The class is called from [[PuduBridge]] when a DEVICE, NETWORK or AWAKE instruction arrives. Its reports are DESCRIBED (32) and NETWORKED (33) of [[Std Mobile Events]], sent through [[PuduBridge]]. The handlers run on the main thread, where the activity is. The request handlers are registered in `cbits/pudu_android_routes.h`.

```java
final class PuduDevice
static final int DESCRIBED = 32, NETWORKED = 33;
static final int WIFI = 1, CELLULAR = 2, WIRED = 3;
static void describe(int tag)
static void watchNetwork(boolean on)
static void keepAwake(boolean on)
```

## Behavior

- DEVICE sends DESCRIBED with the tag, a text of five lines and detail set to the rounded font scale of the configuration, times 100. The lines are `android`, the release from `Build.VERSION`, the manufacturer and model from `Build` joined by one space, the language tag of the default locale, and the identifier of the default time zone.
- NETWORK 1 registers a default network callback on `ConnectivityManager`. The transport of the network is mapped to `WIFI` for Wi-Fi, `CELLULAR` for cellular, and `WIRED` for any other transport. A report is sent when the kind changes. Loss of the network is sent as `Offline`, code 0.
- When no network is active at the start of watching, the host sends code 0 at once.
- NETWORK 0 unregisters the callback. No later report is sent from it.
- Reports are posted on the main thread.
- AWAKE adds or clears `WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON` on the activity window.
- The manifest declares `android.permission.ACCESS_NETWORK_STATE`. It is a normal permission, granted at install, so no prompt is shown.

## Invariants

- Each DEVICE sends exactly one DESCRIBED under its tag.
- Every instruction runs on the main thread in stream order.
- At most one network callback is registered at a time. A second start replaces the first.

## Negative Logic

- No network request or reading of traffic. The class reads the transport of the active network only.
- No reporting of a link code above 3. The transports map to 1, 2 and 3 only.
- No keep-awake lease. The flag holds until the next AWAKE, and the platform clears it when the window leaves the foreground.
- No reading of a precise location, address or network name for the facts.

## Dependencies and consumers

Depends on `android.os.Build`, `android.net.ConnectivityManager` and `NetworkCapabilities`, `android.content.res.Configuration`, `java.util.Locale`, `java.util.TimeZone`, and `android.view.WindowManager`. Called by [[PuduBridge]]; the activity is [[PuduActivity]]. Its iOS counterpart is [[pudu-ios-device]]. Program side: [[Std Mobile Device]].

## Resolved Grill Log

- **Q:** Why does the host report the link kind rather than connectivity alone? **A:** The transport is available from the same callback at no extra cost, and a program that defers large transfers to Wi-Fi needs it. A boolean would discard that information.
- **Q:** Why is the network permission declared without a prompt? **A:** It is a normal permission, granted at install. Declaring it for every program costs nothing at run time and needs no user decision.
- **Q:** Why does a missing active network answer at once? **A:** The default-network callback reports only changes. A program that starts watching while offline would otherwise wait with no answer.

## Referenced by

[[src/android/org/pudu/_MOC]] · [[PuduBridge]] · [[PuduActivity]] · [[pudu-ios-device]] · [[Std Mobile Device]] · [[About Example]] · [[NATIVE-MOBILE]]
