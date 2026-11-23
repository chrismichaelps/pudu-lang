---
type: module
path: "@root/packages/pudu/v0.1/android/org/pudu/PuduTabs.java"
fidelity: Active
subsystem: "[[Backend]]"
tags: [module, native, android, navigation, tabs]
aliases: [PuduTabs, Native Android Tabs]
---

# PuduTabs

## Purpose and interface

The tab bar of a Pudu Native application on Android: a stack per tab under a platform toolbar, the tab titles in a bar along the bottom, and at most one sheet dialog over everything. The program owns the tabs, their routes and the selection. A person's pick of a tab is applied at once and reported as SELECTED. The class is called from [[PuduBridge]] when a TABS instruction has been read and checked by [[pudu-android-routes]]. Its reports go through [[PuduBridge]] as SELECTED (29) and POPPED (14) of [[Std Mobile Events]], and DISMISSED (15) for the sheet. It runs on the main thread, where the activity is. Its single-stack counterpart is [[PuduNavigator]]; its iOS counterpart is [[pudu-ios-tabs]].

```java
final class PuduTabs
static final int SELECTED = 29;
static void show(int[] ids, String[] names, int[] counts, int[] routes, View[] bodies, boolean[] fills, String[] titles,
    int chosen, boolean hasSheet, int sheetId, View sheetView, boolean sheetFills)
static boolean shown()
static View top()
static void close()
```

## Behavior

- `show` receives the tabs already checked: the tab ids, tab titles, page counts, route ids, bodies, the fill flags, page titles, the chosen tab id, and the sheet as its flag, id, body and fill flag. Each tab's pages are split from the flat arrays by the page counts, in bar order.
- Each tab has one stack. Its pages are reused by route id, and the stack's ids are replaced by the new route ids. The selected tab is the one whose id equals the chosen id.
- The tab titles are shown in a bar of borderless buttons along the bottom. Android has no system symbol set, so a tab shows its title only. A tap on a tab title selects that tab. The selection is applied at once and SELECTED is sent with the tab id as its tag. A selection the program makes is not reported.
- The toolbar shows the selected stack's top page title. Its up affordance pops the selected stack. A pop removes the top route and sends POPPED with the removed route as the tag and the surviving route as the detail.
- System back pops the selected stack the same way. On API 33 and later, the host registers an `OnBackInvokedCallback` only while the selected stack can pop and no sheet is shown, and unregisters it otherwise, so back falls through to the activity when no tab page can go back.
- The sheet is a `Dialog` over everything. A same-id sheet with the same body is kept. A changed sheet cancels the current dialog and shows the replacement. A dismissal of the current sheet ends it and sends DISMISSED with the route id as its tag. A dismissal of an earlier sheet is ignored.
- `close` ends the tabs when a NAVIGATE or a ROOT replaces them. It cancels any sheet, unregisters the back callback, and clears the stacks. A pending SELECTED, POPPED or DISMISSED is unqueued by the routes before the tabs are closed.
- The tabs and the single-stack navigator close each other. Showing tabs closes the navigator, and showing the navigator closes the tabs.

## Invariants

- Each SELECTED, POPPED and DISMISSED carries the tab or route id of the request it reports.
- A stack's route ids equal the route ids last shown for it, so a programmatic change reports nothing.
- The back callback is registered only while a pop is possible, so system back never has to be ignored by the host.
- The tabs are changed only on the main thread.

## Negative Logic

- No symbols. Android has no system symbol set, so the program's symbol is read and discarded by [[pudu-android-routes]].
- No report for a programmatic selection, push, pop or sheet change.
- No outcome for the sheet beyond its dismissal. The dialog does not report what the person did inside it.
- No refusal here. Each refusal is made by [[pudu-android-routes]] before this class is called.

## Dependencies and consumers

Depends on `android.app.Dialog`, the toolbar and button views of the platform, `android.window.OnBackInvokedCallback` and `OnBackInvokedDispatcher` on API 33 and later, and the activity of [[PuduActivity]]. Called by [[PuduBridge]] after [[pudu-android-routes]] reads TABS. Program side: [[Std Mobile Navigation]] and [[Std Mobile Stream]].

## Resolved Grill Log

- **Q:** Why titles only in the bottom bar? **A:** Android has no system symbol set that the program can name, so a symbol would need an asset per tab. The title alone is the one label every tab has.
- **Q:** Why does back pop the selected stack and not leave the tabs? **A:** Back on a tab page is a pop inside that tab, the same as the up affordance. Leaving the application is the activity's own back, which runs only when no tab page can pop.
- **Q:** Why register the back callback only when a pop is possible? **A:** On API 33 and later a registered callback takes back from the platform. Registering it only while a pop can happen leaves back to the activity at the root of every tab.
- **Q:** Why does the bar and the single stack close each other? **A:** Both describe the whole screen. Keeping one of them at a time means one owner of the content view, so no two navigators fight over it.
- **Q:** Why is the sheet a dialog and not a bottom sheet? **A:** The contract names one page sheet over the bar. A dialog covers everything, as the iOS page sheet does, with one dismissal the host can report.

## Referenced by

[[PuduBridge]] · [[PuduNavigator]] · [[PuduActivity]] · [[pudu-android-routes]] · [[pudu-ios-tabs]] · [[Std Mobile Navigation]] · [[Tabs Example]] · [[Native Tabs]] · [[NATIVE-MOBILE]]
