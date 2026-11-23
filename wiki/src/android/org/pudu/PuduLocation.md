---
type: module
path: "@root/packages/pudu/v0.1/android/org/pudu/PuduLocation.java"
fidelity: Active
subsystem: "[[Backend]]"
tags: [module, native, android, location]
aliases: [PuduLocation, Native Android Location]
---

# PuduLocation

## Purpose and interface

Device location on the Android host. The class is called from [[PuduBridge]] when a LOCATE or TRACK instruction arrives. Its report is LOCATED (34) of [[Std Mobile Events]], sent through [[PuduBridge]]. The handlers run on the main thread, where the activity is. The request handlers are registered in `cbits/pudu_android_routes.h`.

```text
final class PuduLocation
static final int LOCATED = 34
static void locate(int tag, int accuracy)
static void track(boolean on, int accuracy, int distance)
```

## Behavior

- The provider is GPS for the precise accuracy. Approximate and coarse requests use the network provider. When the preferred provider is not enabled, the host falls back to whichever provider is enabled.
- The fine or coarse location permission is checked with the permission check of the activity. When neither is granted, LOCATE answers `None` at once.
- LOCATE is one-shot. Location updates are requested on the main looper, and the first fix answers the tag and removes the request.
- A thirty-second timeout answers `None` when no fix arrives.
- A last-known fix younger than sixty seconds answers at once, before any request is made.
- TRACK requests location updates with the minimum distance given. When tracking is turned off, the updates are removed.
- A LOCATED report carries detail 1 and four words for a position, or detail 0 with no words when no position is available.

## Invariants

- Each LOCATE sends exactly one LOCATED under its tag.
- Every instruction runs on the main thread in stream order.
- At most one tracking request is registered at a time. A second TRACK replaces the first.
- The position words match the order of the stream: ten-millionths of the latitude, ten-millionths of the longitude, the rounded-up horizontal accuracy and the altitude.

## Negative Logic

- No prompt for permission. The request for it is made by the permission module, not by a locate request.
- No fix older than sixty seconds is presented as current.
- No reverse geocoding, address or place name is read or sent.
- No background location. Tracking runs only while the program's activity is in front.

## Dependencies and consumers

Depends on the location service of the platform (`LocationManager`, `Location`), `android.content.pm` and the activity permission check, and `android.os.Looper`. Called by [[PuduBridge]]; the activity is [[PuduActivity]]. Its iOS counterpart is [[pudu-ios-location]]. Program side: [[Std Mobile Location]].

## Resolved Grill Log

- **Q:** Why is the last-known fix reused only when it is fresh? **A:** An old fix presented as current would mislead the program about where the device is. A fix under sixty seconds is close enough to answer at once.
- **Q:** Why does a missing permission answer at once? **A:** The host cannot obtain a fix without the permission, and a waiting tag would otherwise wait for the timeout for no reason.
- **Q:** Why is there a thirty-second timeout? **A:** A device indoors or with location services stalled can produce no fix. The timeout guarantees each tag is released.
- **Q:** Why are provider choices made per accuracy? **A:** The precise provider is the only one that yields the finest fix. Approximate and coarse requests take the network provider, which is cheaper, and fall back when a provider is off.

## Referenced by

[[src/android/org/pudu/_MOC]] · [[PuduBridge]] · [[PuduActivity]] · [[pudu-ios-location]] · [[Std Mobile Location]] · [[Where Example]] · [[NATIVE-MOBILE]]
