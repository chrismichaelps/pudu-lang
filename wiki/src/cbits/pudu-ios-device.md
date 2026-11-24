---
type: module
path: "@root/packages/pudu/v0.1/cbits/pudu_ios_device.h"
fidelity: Active
domain: "[[Pudu Native]]"
subsystem: "[[Native Mobile Targets]]"
tags: [module, host, ios, native, device, network, objective-c]
aliases: [pudu-ios-device, iOS Host Device]
---

# pudu-ios-device

## Purpose and interface

Device facts, network reachability and keep-awake of the iOS host. Included once by [[iOS Host Adapter]] in `pudu_ios_host.m`. The compiler stages it with the other private headers ([[Native Toolchain Host Sources]]). It implements the handlers of instructions DEVICE (58), NETWORK (59) and AWAKE (60) of [[Std Mobile Stream]]. Its reports are DESCRIBED (32) and NETWORKED (33) of [[Std Mobile Events]], queued through [[iOS Host Events]].

```text
static void pudu_do_device(pudu_reader *reader)
static void pudu_do_network(pudu_reader *reader)
static void pudu_do_awake(pudu_reader *reader)
static NSString *pudu_device_model(void)
static uint32_t pudu_link_code(nw_path_t path)
```

## Behavior

- DEVICE names the tag. It queues DESCRIBED with the tag, a text of five lines and detail set to the preferred text scale. The lines are the platform `ios`, the system version from `UIDevice`, the model, the first preferred language from `NSLocale` (falling back to `en`), and the identifier of the local time zone.
- The model is the `SIMULATOR_MODEL_IDENTIFIER` environment value on the simulator, because the machine name reports the host CPU there. On a device it is the machine name from `uname`, such as `iPhone17,1`.
- The text scale is the rounded value of the default `UIFontMetrics` scaling of 100.
- NETWORK 1 starts an `nw_path_monitor` on the main queue. The link is `Offline` when the path is not satisfied, `Wifi` or `Cellular` by the interface type of the path, and `Wired` for any other interface. A report is queued only when the link kind changes. It queues NETWORKED with tag 0 and the link code.
- NETWORK 0 cancels the monitor. No later report is queued from it.
- AWAKE sets `UIApplication.sharedApplication.idleTimerDisabled` to the flag. The setting is held until the next AWAKE.
- With the environment variable `PUDU_UI_DEVICE_TEST` set, each AWAKE prints `PUDU_DEVICE awake yes` or `PUDU_DEVICE awake no` to standard output, so the simulator suite can observe the setting.
- The self-test `pudu_test_device` waits until the monitor has queued a NETWORKED (counter `pudu_networked_count`), for up to 10 seconds, and then stops the program.

## Invariants

- Each DEVICE queues exactly one DESCRIBED under its tag.
- Every handler runs on the main thread in stream order. A report reflects the setting as it stood when the instruction arrived.
- The monitor is held by one handler. A second NETWORK 1 while watching reports the last known link at once and does not start a second monitor.

## Negative Logic

- No retry of a failed monitor start. The program is not told; no report arrives.
- No request for a network permission. Reachability needs no prompt on this platform.
- No reading of addresses, SSIDs or the content of traffic. The monitor reports the interface kind only.
- No timer for keep-awake. The platform clears the flag when the app leaves the foreground, and the host does not reapply it.

## Dependencies and consumers

Depends on Foundation (`NSLocale`, `NSTimeZone`, `NSString`), UIKit (`UIDevice`, `UIApplication`, `UIFontMetrics`), Network (`nw_path_monitor`, `nw_path_get_status`, `nw_path_uses_interface_type`), [[iOS Host Events]] for the queue, and [[pudu-ios-kinds]] for the instruction table. The Network framework joins the host frameworks declared in the toolchain. Included by [[iOS Host Adapter]]. Program side: [[Std Mobile Device]], [[Std Mobile Stream]] and [[Std Mobile Events]].

## Resolved Grill Log

- **Q:** Why does the model come from the simulator environment on the simulator? **A:** The machine name reports the host processor when the app runs in the simulator, so a program would read the wrong hardware. The environment value names the simulated device.
- **Q:** Why does the monitor report only on a change of link kind? **A:** Path updates for the same interface kind carry no new information for the program. Reporting them would only wake the program.
- **Q:** Why does keep-awake hold no timer? **A:** The platform clears the idle-timer setting when the app leaves the foreground. The host sets the flag as asked and leaves the lifetime to the program.
- **Q:** Why wait for the first network report? **A:** The monitor answers asynchronously; stopping on a fixed delay can end the program before its link is shown. _Rejected:_ a longer fixed delay.

## Services (#989)

- Battery: UIDevice battery monitoring is enabled for the request. POWERED 39 reports the charge state and the level in percent, -1 when unknown. The simulator reports unknown.
- Brightness: the UIScreen brightness is set from the percent. The platform's own value returns when the application leaves the front. A percent above 100 is refused with `set brightness to <n>`.
- Orientation: the static mask `pudu_orientation_mask` in [[pudu-ios-scene]] is set from the code, and the root controller is asked to update its geometry. A code above 2 is refused with `locked unknown orientation <n>`.
- Motion: a CMMotionManager accelerometer on the main queue reports SENSED 40 in milli-g at the requested interval. The simulator has no accelerometer, so nothing is reported there. A flag above 1 is refused with `set motion sensing to <n>`.
- Self-test counter: `pudu_powered_count` counts POWERED reports. The services self-test in [[pudu-ios-media]] reads it.

## Referenced by

[[src/cbits/_MOC]] · [[iOS Host Adapter]] · [[Std Mobile Device]] · [[Std Mobile Stream]] · [[Std Mobile Events]] · [[About Example]] · [[Uses Mobile Device]] · [[NATIVE-MOBILE]]
