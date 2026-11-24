---
type: module
path: "@root/packages/pudu/v0.1/cbits/pudu_ios_location.h"
fidelity: Active
domain: "[[Pudu Native]]"
subsystem: "[[Native Mobile Targets]]"
tags: [module, host, ios, native, location]
aliases: [pudu-ios-location, iOS Host Location]
---

# pudu-ios-location

## Purpose and interface

Device location of the iOS host. Included once by [[iOS Host Adapter]] in `pudu_ios_host.m`, after the permission header. The compiler stages it with the other private headers ([[Native Toolchain Host Sources]]). It implements the handlers of instructions LOCATE (61) and TRACK (62) of [[Std Mobile Stream]]. Its report is LOCATED (34) of [[Std Mobile Events]], queued through [[iOS Host Events]].

```text
static void pudu_do_locate(pudu_reader *reader)
static void pudu_do_track(pudu_reader *reader)
static void pudu_location_answer(uint32_t tag, CLLocation *location)
```

## Behavior

- The real code is compiled only under `PUDU_PERMISSION_LOCATION` or `PUDU_PERMISSION_LOCATION_ALWAYS`. Otherwise the handlers are stubs: LOCATE answers `Located(tag, None)` and TRACK is ignored.
- The header owns its own location manager and delegate, separate from the permission manager.
- LOCATE is one-shot. Its tag waits in a pending list and a single location request is made with the accuracy of the request. The first location answers every pending tag with that location.
- While tracking, a LOCATE answers at once from the manager's last location when one exists, and the location updates that follow answer tag 0.
- A location failure answers the pending tags with `None`. The unknown-location failure is ignored while tracking, because updates continue.
- A location with a negative horizontal accuracy is invalid and answers `None`.
- TRACK sets the desired accuracy and distance filter, then starts or stops location updates.
- With the environment variable `PUDU_UI_LOCATION_TEST` set, the self-test waits up to 10 seconds until a LOCATED has been queued, prints `PUDU_LOCATION answered <count>` to standard output, and stops.

## Invariants

- Each LOCATE queues exactly one LOCATED under its tag.
- Every handler runs in stream order on the thread the host uses for its queue.
- The position words are the ten-millionths of the coordinates, the rounded-up horizontal accuracy and the altitude, in that order.

## Negative Logic

- No prompt for permission. The handler reads the request state; the permission module makes the request.
- No retry of a failed location request. A failure is answered with `None`.
- No reverse geocoding, place names or address data. The host reports coordinates only.
- No timer on tracking. Updates run until the program turns them off.

## Dependencies and consumers

Depends on CoreLocation (`CLLocationManager`, `CLLocation`), Foundation, [[iOS Host Events]] for the queue, and [[pudu-ios-kinds]] for the instruction table. The location framework is linked only when the location permission kind is declared. Included by [[iOS Host Adapter]]. Program side: [[Std Mobile Location]], [[Std Mobile Stream]] and [[Std Mobile Events]].

## Resolved Grill Log

- **Q:** Why does the host keep its own location manager rather than share the permission manager? **A:** The permission manager answers the permission state. A location request is a separate concern, and sharing one object would couple a prompt to every position request.
- **Q:** Why are pending tags answered together? **A:** One location request can satisfy several waiting tags. Answering each from the same fix keeps every tag released at once.
- **Q:** Why is a negative horizontal accuracy an error? **A:** The platform marks such a location as invalid. Reporting its coordinates would present a position the device does not stand behind.
- **Q:** Why is the unknown-location failure ignored while tracking? **A:** Updates continue after that failure, so a later fix will arrive. Answering pending tags with `None` at that point would end a stream that is still live.

## Referenced by

[[src/cbits/_MOC]] · [[iOS Host Adapter]] · [[Std Mobile Location]] · [[Std Mobile Stream]] · [[Std Mobile Events]] · [[Where Example]] · [[Uses Mobile Location]] · [[NATIVE-MOBILE]]
