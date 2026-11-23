---
type: module
path: "@root/packages/pudu/v0.1/android/org/pudu/PuduWeb.java"
fidelity: Active
subsystem: "[[Backend]]"
tags: [module, native, android, web, media]
aliases: [PuduWeb]
---

# PuduWeb

## Purpose and interface

The web pages, video, audio, keyboard dismissal and back gesture of the Android host (#990). The class is called from [[PuduBridge]] for LOAD, MEDIA, AUDIO, KEYBOARD and BACK, through the handlers registered in [[pudu-android-services]]. It creates the WebView for kind WEB and the VideoView for kind VIDEO through the factories in [[pudu-android-kinds]]. Its reports are LOADED (42), ENDED (43) and BACKED (44) of [[Std Mobile Events]]. The handlers run on the main thread.

## Behavior

- WEB is a WebView with JavaScript enabled and a WebViewClient. onPageFinished sends LOADED with detail 1. onReceivedError for the main frame sends LOADED with detail 0. Bundled pages load from `file:///android_asset/`, and remote pages load by their URL.
- VIDEO is a VideoView. Looping is set on its prepared MediaPlayer. Completion of a video that does not loop sends ENDED with its tag.
- AUDIO keeps a MediaPlayer per tag. A remote source loads by URL, and a bundled source loads through the asset file descriptor. Completion loops the sound or sends ENDED with the tag.
- KEYBOARD asks the InputMethodManager to hide the soft input of the focused view.
- BACK set to 1 makes PuduActivity's back press send BACKED with tag 0, instead of the platform's action. On API 33 and later, an OnBackInvokedCallback at overlay priority does the same. BACK set to 0 returns the gesture to the platform.

## Invariants

- Each load answers once with LOADED, detail 1 or 0.
- A sound under a tag is replaced when AUDIO plays under that tag again.
- Back is consumed only while BACK is 1. With BACK at 0 the platform's action runs unchanged.

## Negative Logic

- No script bridge. The page cannot call the program, and the program cannot run script in the page.
- No report for navigation inside a page. Only the load requested by the program is answered.
- No default back handling. The platform's back behavior and the navigation stack stay intact until the program asks.

## Dependencies and consumers

Depends on WebView, VideoView, MediaPlayer, InputMethodManager, OnBackInvokedCallback (API 33 and later), the back press and resume path of [[PuduActivity]], [[PuduBridge]] for the call, and the INTERNET permission already declared in the manifest. Called by [[PuduBridge]]. Its counterpart on iOS is [[pudu-ios-web]]. Program side: [[Std Mobile Control]], [[Std Mobile Media]], [[Std Mobile System]] and [[Std Mobile Request]]. Example: [[Viewer Example]].

## Resolved Grill Log

- **Q:** Why does the back callback sit at overlay priority on API 33 and later? **A:** The program's answer must win over the platform's own back action. Overlay priority puts the callback ahead of the default handler, so BACKED replaces the action only while the program holds back.
- **Q:** Why is a failed main frame answered with LOADED 0 rather than ignored? **A:** The program waits on the tag. A load that fails without an answer would hold that wait forever.
- **Q:** Why are bundled pages read from `file:///android_asset/`? **A:** The rule for sources is the same as for images. A source with a scheme is remote, and any other text names a file the application bundles.

## Referenced by

[[PuduBridge]] · [[PuduActivity]] · [[pudu-android-services]] · [[pudu-android-kinds]] · [[pudu-ios-web]] · [[Std Mobile Control]] · [[Std Mobile Media]] · [[Viewer Example]] · [[NATIVE-MOBILE]]
