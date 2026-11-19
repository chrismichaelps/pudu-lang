---
type: module
path: "@root/packages/pudu/v0.1/cbits/pudu_ios_permission.h"
fidelity: Active
domain: "[[Pudu Native]]"
subsystem: "[[Native Mobile Targets]]"
tags: [module, host, ios, native, permission, objective-c]
aliases: [iOS Host Permission, pudu-ios-permission]
---

# pudu-ios-permission

## Purpose and interface

Permission requests of the iOS host: the state of each declared kind, the request that asks the person, and the settings page. Included once by [[iOS Host Adapter]]. The compiler stages it with the other private headers ([[Native Toolchain Host Sources]]). It implements the handlers of PERMISSIONS 51, PERMISSION 52 and SETTINGS 53 of [[Std Mobile Stream]]. Its reports are PERMISSIONED 28 of [[Std Mobile Events]], queued through [[iOS Host Events]] with the kind as the tag and the state as the detail.

Each kind's code is compiled only when the application declares it: `#if PUDU_PERMISSION_<KIND>`. An undeclared kind has no status or request function and no entry in the operations table.

```text
static void pudu_permission_report(uint32_t kind, uint32_t state)
static void pudu_permission_check(uint32_t count, const uint32_t *kinds)
static void pudu_permission_request(uint32_t kind)
static void pudu_permission_settings(void)
static void pudu_ui_permission_test(void)
```

Kind and state codes match [[Std Mobile Permission]]: kinds 0 to 10 in declaration order, states 0 to 6 as NotAsked, Granted, Limited, Provisional, Denied, Blocked, Unavailable.

## Behavior

- Platform state mapping:
  - Camera, microphone, contacts, calendar and motion: notDetermined maps to NotAsked, restricted to Unavailable, denied to Blocked, authorized to Granted.
  - Photos and photos-add: limited access maps to Limited. Write-only calendar access maps to Limited.
  - Location: reduced accuracy maps to Limited.
  - Notifications: provisional authorization maps to Provisional. Denied maps to Blocked, since iOS asks once.
- Always location is a two-step request. The while-using prompt is asked first; the upgrade to always is asked only after it is granted. An upgrade the person declines resolves when the application becomes active again. Whether always was asked is remembered in user defaults, so the state reads Denied before the first ask and Blocked after it.
- Bluetooth is asked by starting a central manager. Its first state update resolves the request.
- Motion is asked by a one-instant activity query. Its answer is the state reported.
- Requests are serialized: one prompt at a time, and only while the application is active. A request that arrives while another is open waits its turn.
- Returning to the foreground re-checks every kind the program has heard about and reports each state that changed.
- PERMISSIONS 51 reads a count and each kind code, then reports each kind's state. PERMISSION 52 asks one kind in its turn. SETTINGS 53 opens the application's page in Settings.
- Refusals are reported as defects through the stream path: `named unknown permission` for a kind code past 10, and `named a permission the application does not declare:` followed by the kind name, when a request names a kind the application did not compile in.

Self-test: `PUDU_UI_PERMISSION_TEST` asks each declared kind once, waits for every state the platform reports, prints each as `PUDU_PERMISSION <kind> <state>` and stops.

## Invariants

- Each PERMISSION request reports exactly one PERMISSIONED for its kind, even when the state was already decided.
- A kind's state is reported to the program only when it differs from the last report, or when the program asks.
- Permission operations run on the main thread, where the platform's callbacks arrive.

## Negative Logic

- No prompt from PERMISSIONS or from a foreground re-check. Only PERMISSION may show a prompt.
- No retry of a refused request. A Blocked kind goes to Settings through SETTINGS, not to another prompt.
- No stored state. The only remembered values are the last reported state per kind and the always-location ask flag.
- No code for an undeclared kind. Its status and request functions are not compiled.

## Dependencies and consumers

Depends on AVFoundation, Photos, CoreLocation, UserNotifications, Contacts, EventKit, CoreBluetooth and CoreMotion, each only for the kinds the application declares; on [[iOS Host Events]] for the queue; and on [[pudu-ios-kinds]] for the instruction table. Included by [[iOS Host Adapter]]. Program side: [[Std Mobile Permission]], [[Std Mobile Stream]] and [[Std Mobile Events]]. Build side: [[Pudu Backend Permissions]], which sets the compile flags and frameworks for each kind.

## Resolved Grill Log

- **Q:** Why compile each kind under its own flag? **A:** A kind's framework is linked only when it is declared. Without the flag the host would link every framework and carry every capability, and an application's binary would ask for access it never requests. The flag is set by [[Pudu Backend Permissions]] from the manifest, so the code and the declaration cannot disagree.
- **Q:** Why is Denied reported as Blocked on iOS? **A:** iOS asks once. A refusal is final from the program's view, because the platform will not prompt again and only Settings can allow the kind. Reporting Denied would invite a request that the platform silently ignores. _Rejected:_ Denied after a first refusal, which would leave the program retrying a prompt that never appears.
- **Q:** Why is always location two requests, and why is the ask remembered? **A:** The platform requires the while-using grant before it will offer always, so a single request cannot reach it. Before the first ask the upgrade reads Denied, because the person can still be asked. After it, the upgrade reads Blocked, because a second prompt would never appear. The platform does not report whether always was asked, so the host remembers it in user defaults.
- **Q:** Why does Bluetooth and motion ask by starting a central manager or querying activity? **A:** Neither framework has a request function. Starting the manager or querying activity is the only call that makes the platform show its prompt, so the host uses it and reads the answer from the state.
- **Q:** Why serialize requests and allow them only while active? **A:** The platform shows one prompt at a time, and a prompt shown in the background is dismissed without an answer. A queued request waits for the next active period, so the program receives an answer for each request.

## Referenced by

[[src/cbits/_MOC]] · [[iOS Host Adapter]] · [[pudu-ios-kinds]] · [[Std Mobile Permission]] · [[Std Mobile Stream]] · [[Std Mobile Events]] · [[Pudu Backend Permissions]] · [[Permissions Example]] · [[NATIVE-MOBILE]]
