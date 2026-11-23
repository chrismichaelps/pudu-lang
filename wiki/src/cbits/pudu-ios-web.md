---
type: module
path: "@root/packages/pudu/v0.1/cbits/pudu_ios_web.h"
fidelity: Active
domain: "[[Pudu Native]]"
subsystem: "[[Native Mobile Targets]]"
tags: [module, host, ios, native, web, media]
aliases: [pudu-ios-web, iOS Host Web]
---

# pudu-ios-web

## Purpose and interface

Web pages, video, audio, keyboard dismissal and the back gesture of the iOS host (#990). Included once by [[iOS Host Adapter]], after the permission header. It creates the kinds WEB (23) and VIDEO (24) of [[pudu-ios-kinds]] and implements the handlers of instructions LOAD (74), MEDIA (75), AUDIO (76), KEYBOARD (77) and BACK (78) of [[Std Mobile Stream]] and [[Std Mobile Request]]. Its reports are LOADED (42), ENDED (43) and BACKED (44) of [[Std Mobile Events]], queued through [[iOS Host Events]]. WebKit and AVFoundation are linked always.

## Behavior

- WEB creates a WKWebView. A shared navigation delegate queues LOADED with the view's tag when the navigation finishes, and when it fails, whether the failure is provisional or committed. Bundled pages load as file URLs with read access to the assets directory.
- VIDEO creates a view whose layer is an AVPlayerLayer with aspect fit, and owns its own AVPlayer. When the item ends and the video loops, playback seeks to zero. When it does not loop, ENDED is queued with the view's tag.
- AUDIO keeps one AVPlayer per tag. Playing 1 replaces any sound under the tag. Playing 0 stops it. The end notification loops the sound or queues ENDED with the tag.
- KEYBOARD ends editing on the key window, which dismisses the on-screen keyboard.
- BACK is read and ignored. iOS has no system back gesture outside navigation.
- The self-test PUDU_UI_WEB_TEST waits up to 10 seconds until a LOADED has been queued, prints `PUDU_WEB loaded <yes|no>` and stops.

## Invariants

- Each LOAD queues exactly one LOADED under its node's tag, on finish or on failure.
- Each VIDEO and AUDIO answers under its own tag. A sound's player is replaced when the tag plays again, never duplicated.
- Every report carries the tag of the node or sound that produced it.

## Negative Logic

- No script bridge. The page and the program share no channel.
- No event for navigation inside a page. Only the load requested by the program is reported.
- No back handling by default. The platform's behavior stays intact until BACK is set to 1, and on iOS the word has no effect.
- No retained web view after the node is removed from the tree.

## Dependencies and consumers

Depends on WebKit (WKWebView and its navigation delegate), AVFoundation (AVPlayer and AVPlayerLayer), the key window for keyboard dismissal, [[iOS Host Events]] for the queue, and [[pudu-ios-kinds]] for the kind and instruction tables. Included by [[iOS Host Adapter]]. Program side: [[Std Mobile Control]], [[Std Mobile Media]], [[Std Mobile System]], [[Std Mobile Stream]], [[Std Mobile Request]] and [[Std Mobile Events]]. Its example is [[Viewer Example]]. Its Android counterpart is [[PuduWeb]].

## Resolved Grill Log

- **Q:** Why does LOADED also report failure? **A:** A program shows progress until the answer. A page that fails must still release the wait, with detail 0 so the program can show the failure.
- **Q:** Why is there one AVPlayer per sound and per video? **A:** Each sound and each video has its own tag and its own end. A shared player would merge their ends and lose the tag that each ENDED carries.
- **Q:** Why is BACK read and ignored here? **A:** iOS has no system back gesture outside navigation, so the word has nothing to replace. The program still receives the same stream on both hosts.
- **Q:** Why does the self-test wait for a LOADED and not for a fixed delay? **A:** A fixed delay measures startup time, not the load. Waiting for the answer checks the path the program relies on.

## Referenced by

[[src/cbits/_MOC]] · [[iOS Host Adapter]] · [[Std Mobile Control]] · [[Std Mobile Media]] · [[Std Mobile System]] · [[Std Mobile Stream]] · [[Std Mobile Request]] · [[Std Mobile Events]] · [[Viewer Example]] · [[PuduWeb]] · [[NATIVE-MOBILE]]
