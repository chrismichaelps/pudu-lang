---
type: module
path: "@root/packages/pudu/v0.1/android/org/pudu/PuduSystem.java"
fidelity: Active
subsystem: "[[Backend]]"
tags: [module, native, android, system, clipboard, intent]
aliases: [PuduSystem, Native Android System]
---

# PuduSystem

## Purpose and interface

System requests on the Android host: opening a URL, the share chooser, the clipboard and the status bar. The class is called from [[PuduBridge]] when an OPEN, SHARE, COPY, PASTE or STATUS instruction arrives, and its reports go through [[PuduBridge]] as OPENED (25), SHARED (26) and PASTED (27) of [[Std Mobile Events]]. It runs on the main thread, where the activity is.

```java
final class PuduSystem
static final int OPENED = 25, SHARED = 26, PASTED = 27;
static void open(Activity activity, int tag, String url)
static void share(Activity activity, int tag, String text)
static void copy(Activity activity, String text)
static void paste(Activity activity, int tag)
static void status(Activity activity, int style, boolean hidden)
```

## Behavior

- `open` builds an `Intent.ACTION_VIEW` on the URL and starts it. When no activity handles the intent, the start fails and OPENED is sent with 0. Otherwise OPENED is sent with 1.
- `share` builds an `Intent.ACTION_SEND` of plain text and starts it through `Intent.createChooser`. SHARED is sent with 1 once the chooser is shown. The host cannot see which target the person chose or whether they finished, so the answer is not the outcome of the share.
- `copy` places the text on the `ClipboardManager` as a plain text clip.
- `paste` reads the primary clip and coerces its first item to text with `coerceToText`. When there is no clip the text is empty. PASTED is sent with the text.
- `status` sets the status bar style through `WindowInsetsController`: automatic follows the night mode of the device, light text sets the appearance so the icons are light, and dark text sets them dark. Hiding and showing use the `statusBars` type of the controller on API 30 and later. Before API 30 the hidden state uses the system UI visibility flags, which hide the status bar through the fullscreen flag.
- A style code outside 0 to 2 is refused with the same defect text as the iOS host.

## Invariants

- OPENED, SHARED and PASTED each carry the tag of the request they answer.
- A status change is applied only from the main thread, where the window is.
- The clipboard is written and read only when the program asks for it.

## Negative Logic

- No outcome for a share. SHARED reports that the chooser was shown, not that anything was shared.
- No retry of a failed open. A missing handler is reported as 0.
- No read of the clipboard except by PASTE.
- No change to the navigation bar. Only the status bar is set.

## Dependencies and consumers

Depends on `android.content.Intent`, `android.content.ClipboardManager`, `android.view.WindowInsetsController` and the system UI flags, and the activity of [[PuduActivity]]. Called by [[PuduBridge]]. Its iOS counterpart is [[pudu-ios-system]]. Program side: [[Std Mobile System]].

## Resolved Grill Log

- **Q:** Why does Android's share answer differ from iOS? **A:** The chooser runs in another application and does not report the target or the outcome to the caller. The only fact the host has is that the chooser opened. The iOS controller reports completion, so the two answers are not the same measure, and the program is told this in [[Std Mobile System]].
- **Q:** Why does automatic follow night mode? **A:** Automatic is the platform's own default. The host leaves the choice to the system so that the status bar matches the theme the person already has.
- **Q:** Why two status bar paths? **A:** API 30 added the controller that hides and shows the status bar. Older versions need the visibility flags, so the host supports both rather than setting a minimum API for this feature.

## Referenced by

[[src/android/org/pudu/_MOC]] · [[PuduBridge]] · [[PuduActivity]] · [[pudu-ios-system]] · [[Std Mobile System]] · [[NATIVE-MOBILE]]
