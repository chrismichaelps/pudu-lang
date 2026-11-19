---
type: module
path: "@root/packages/pudu/v0.1/android/org/pudu/PuduNavigator.java"
fidelity: Active
subsystem: "[[Backend]]"
tags: [module, native, android, navigation, toolbar, dialog]
aliases: [PuduNavigator, Native Android Navigator]
---

# PuduNavigator

## Purpose and interface

The native page stack and page sheet of the Android host. The program names the routes root first, each with a body view and a title, and an optional sheet. The top route's body is shown under a platform `Toolbar`. Its up affordance, and system back, pop one route. The class is called from `PuduBridge.navigate`, `PuduBridge.navigationTop` and the activity's back handling, all of them on the main thread. It is realized by [[pudu_android_routes.h]], which checks each NAVIGATE before this class sees it.

```java
final class PuduNavigator
static final int POPPED = 14, DISMISSED = 15;
static void show(int[] ids, View[] views, boolean[] filling, String[] named, boolean hasSheet, int sheetId, View sheetView, boolean sheetFills)
static View top()
static boolean shown()
static boolean back()
```

## Behavior

- `show` installs the page on first use: a vertical `LinearLayout` holding the toolbar and a `FrameLayout` area, placed as the only child of the activity's surface. It then records the route arrays, shows the top route, and opens or closes the sheet.
- The top route's title is set on the toolbar. The up indicator is the theme's `homeAsUpIndicator`, read with `obtainStyledAttributes`, and is shown only when there is a route below. Its content description is the title of that route below.
- The body is detached from any previous parent before it is added to the area. A body that is already the only child of the area is not re-added. A body that fills is laid out match-parent; otherwise it is centered at wrap size.
- A sheet is a `Dialog` without a title. It holds the sheet body, is cancelable by an outside touch, and is shown at full width, full height when it fills, else wrap height. Showing a new sheet closes the old one first. A sheet with the same route and body as the current one is kept.
- `back` pops the page as the person asked. A shown sheet is cancelled, which reports DISMISSED through its cancel listener. Otherwise the stack pops when it holds two or more routes: the accepted arrays are trimmed by one, the top is redrawn, and `PuduBridge.event(POPPED, top, null, destination, null)` is sent. The destination is the route id that is now on top. The method returns false when the stack has one route, so the caller can fall through to the platform.
- The accepted stack is the last presentation trimmed by the pops already reported. A program answer that presents the trimmed stack changes nothing. A program answer that presents the older stack restores the popped routes.
- A sheet cancelled by the person reports DISMISSED with its route id. The cancel listener checks that the dialog is still the current sheet, so a late report about an earlier sheet cannot close its replacement. A sheet closed by the program is dismissed with `closeSheet`, which clears the record before calling `dismiss`, so no event is sent for it.
- System back on API 33 and later: `track` registers an `OnBackInvokedCallback` at `PRIORITY_DEFAULT` only while there is no sheet and more than one route is accepted, and unregisters it when neither holds. Below API 33 the activity's `onBackPressed` calls `back` first and falls back to the platform when it returns false.
- The toolbar's navigation click calls `back`.

## Invariants

- The shown page, the sheet and the accepted arrays always describe the same presentation: a body is in the area or in the dialog, never both.
- A POPPED or DISMISSED report names a route of the accepted stack at the moment it is sent.
- The system back callback is registered only while a pop is possible, so system back leaves the activity when there is nothing to pop.

## Negative Logic

- No pop when the stack holds one route. `back` returns false and the platform handles back.
- No DISMISSED for a sheet the program closed. Only the person's cancel reports.
- No support library. The toolbar, dialog and back dispatcher are platform classes, since the package carries no support libraries.

## Dependencies and consumers

Depends on the platform `android.widget.Toolbar`, `android.app.Dialog`, `android.window.OnBackInvokedDispatcher` and `android.os.Build`, on [[PuduBridge]] for the activity, the surface, `detach` and `event`, and on [[PuduActivity]] for `onBackPressed`. Realized by [[pudu_android_routes.h]], whose NAVIGATE handler calls `PuduBridge.navigate`. The iOS equivalent is [[pudu_ios_navigation.h]].

## Resolved Grill Log

- **Q:** Why are the toolbar, dialog and back dispatcher platform classes rather than support library widgets? **A:** The APK carries no support libraries. The platform classes exist on the minimum API the package targets, and the back dispatcher is used only where it exists.
- **Q:** Why does a user pop apply at once and report afterwards? **A:** The screen must answer the person's gesture without waiting for a round trip through the program. The program then decides with its answer whether the trimmed stack stands.
- **Q:** Why does a cancelled sheet report only when it is still current? **A:** A sheet replaced by the program is dismissed by the program; a late cancel report for it would make the program dismiss its successor.

## Referenced by

[[src/android/org/pudu/PuduActivity]] · [[src/cbits/pudu-android-routes]] · [[NATIVE-MOBILE]]
