---
type: module
path: "@root/packages/pudu/v0.1/android/org/pudu/PuduPermission.java"
fidelity: Active
subsystem: "[[Backend]]"
tags: [module, native, android, permission]
aliases: [PuduPermission, Native Android Permission]
---

# PuduPermission

## Purpose and interface

Permission requests of the Android host: the state of each kind, the request that asks the person, and the settings page. The class is called from [[PuduBridge]] when PERMISSIONS 51, PERMISSION 52 or SETTINGS 53 arrives. Its reports are PERMISSIONED 28 of [[Std Mobile Events]], sent through [[PuduBridge]] with the kind as the tag and the state as the detail. Kind and state codes match [[Std Mobile Permission]].

```java
final class PuduPermission
static final int PERMISSIONED = 28;
static final int CAMERA = 0, MICROPHONE = 1, PHOTOS = 2, PHOTOS_ADD = 3, LOCATION = 4, LOCATION_ALWAYS = 5,
    NOTIFICATIONS = 6, CONTACTS = 7, CALENDAR = 8, BLUETOOTH = 9, MOTION = 10;
static final int NOT_ASKED = 0, GRANTED = 1, LIMITED = 2, PROVISIONAL = 3, DENIED = 4, BLOCKED = 5, UNAVAILABLE = 6;
static String[] needed(int kind)
static int state(int kind)
static void check(int[] kinds)
static void request(int kind)
static void answered(int code)
static void resumed()
static void settings()
```

## Platform permissions by API level

| Kind | Permissions | API level |
|---|---|---|
| Camera | CAMERA | all |
| Microphone | RECORD_AUDIO | all |
| Photos | READ_MEDIA_IMAGES and READ_MEDIA_VISUAL_USER_SELECTED | 34 and later |
| Photos | READ_MEDIA_IMAGES | 33 |
| Photos | READ_EXTERNAL_STORAGE | below 33 |
| PhotosAdd | none | above 28 |
| PhotosAdd | WRITE_EXTERNAL_STORAGE | 28 and below |
| Location | ACCESS_COARSE_LOCATION and ACCESS_FINE_LOCATION | all |
| LocationAlways | ACCESS_BACKGROUND_LOCATION, asked only after foreground location is granted | 29 and later |
| Notifications | POST_NOTIFICATIONS | 33 and later; below 33 read through areNotificationsEnabled |
| Contacts | READ_CONTACTS | all |
| Calendar | READ_CALENDAR and WRITE_CALENDAR | all |
| Bluetooth | BLUETOOTH_CONNECT and BLUETOOTH_SCAN | 31 and later |
| Motion | ACTIVITY_RECOGNITION | 29 and later |

## Behavior

- `state` maps the platform's answer to a state. Coarse-only location reads Limited. Photos with user-selected access on API 34 and later read Limited.
- A kind with no platform permission at this API level, such as photos-add above 28, reads Granted at once.
- NotAsked and Blocked are told apart by remembering each kind's first request in `SharedPreferences` under `org.pudu.permission`. A kind refused with a rationale to show reads Denied; refused without one, and asked before, reads Blocked. A kind never asked reads NotAsked.
- `request` asks one kind at a time, and only while the activity is in front. A request that arrives while another is open waits in a queue.
- `answered` reads the result of `onRequestPermissionsResult`, reports the kind's new state and starts the next queued request.
- `resumed` re-checks every kind the program has heard about and reports each state that changed. It runs from `onResume`.
- `settings` opens the application's details page in the platform settings, the only place a Blocked kind can be allowed.

## Invariants

- Each PERMISSION request reports one PERMISSIONED for its kind, carrying the same tag as the request.
- Requests use the activity's `requestPermissions` call with one request code, so every answer comes back through `answered`.
- The kind table holds the last state reported per kind; a state is reported again only when it changes or is asked.

## Negative Logic

- No prompt from check or resumed. Only `request` shows a prompt.
- No retry of a Blocked kind. The program sends the person to settings.
- No stored state beyond the first-request flags. The platform is the source of the state.
- No permission for an API level that does not need it. The request list is empty at that level, so nothing is declared at run time.

## Dependencies and consumers

Depends on `android.Manifest.permission` names, `android.content.SharedPreferences`, the activity of [[PuduActivity]] and the status of [[PuduBridge]]. Called by [[PuduBridge]]. Build side: the manifest entries of [[Backend Toolchain Android]], written from [[Pudu Backend Permissions]]. The iOS counterpart is [[pudu-ios-permission]]. Program side: [[Std Mobile Permission]].

## Resolved Grill Log

- **Q:** Why remember each kind's first request? **A:** Android reports a refused permission the same way whether the person refused once or twice with "don't ask again". The only signal is whether a rationale may be shown. A refusal with no rationale after an earlier ask is the never-ask-again case, so the host stores that a request was made. _Rejected:_ treating every refusal as Denied, which would leave the program prompting a permission that never shows.
- **Q:** Why does background location wait for foreground location? **A:** The platform refuses the background permission unless the foreground location grant is already held. Asking both at once fails the background request silently. The host asks the background permission only after the foreground answer is Granted or Limited.
- **Q:** Why check every kind on resume? **A:** The person can change a permission in settings and return. The application is not told, so the host re-reads each kind it has been asked about on resume and reports the changes.
- **Q:** Why are the older storage and Bluetooth permissions bounded by a maximum level in the manifest? **A:** Those permissions were replaced by newer ones and are ignored at the higher levels. Bounding them keeps the manifest from asking for storage access on a device that never uses it, which the store review rejects.

## Referenced by

[[src/_MOC]] · [[PuduBridge]] · [[PuduActivity]] · [[pudu-ios-permission]] · [[Std Mobile Permission]] · [[Pudu Backend Permissions]] · [[Permissions Example]] · [[NATIVE-MOBILE]]
