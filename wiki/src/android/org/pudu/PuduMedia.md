---
type: module
path: "@root/packages/pudu/v0.1/android/org/pudu/PuduMedia.java"
fidelity: Active
subsystem: "[[Backend]]"
tags: [module, native, android, media]
aliases: [PuduMedia]
---

# PuduMedia

## Purpose and interface

The in-app browser, speech and image picking of the Android host (#989). The class is called from [[PuduBridge]] for BROWSE, SPEAK, HUSH and PICK_IMAGE, through the handlers registered in [[pudu-android-services]]. Its reports are BROWSED (37), SPOKE (38) and IMAGE_PICKED (41) of [[Std Mobile Events]]. The handlers run on the main thread.

## Behavior

- BROWSE starts an ACTION_VIEW intent for the URL. BROWSED is queued when [[PuduActivity]] resumes after the browser returns.
- SPEAK sends an utterance to TextToSpeech. Utterances requested before the engine is ready are held and sent when it reports ready. SPOKE is queued from the utterance's done callback with `1`, or from its stop callback with `0`.
- HUSH stops the engine's current utterance. The interrupted utterance answers SPOKE with `0`.
- PICK_IMAGE starts an ACTION_GET_CONTENT intent restricted to `image/*`. The result is copied into the cache directory and IMAGE_PICKED carries its path. A cancelled pick answers with `0` and empty text.
- The rate is applied to the engine from the percent given, relative to the engine's normal rate.

## Invariants

- Each BROWSE, SPEAK and PICK_IMAGE queues exactly one answer under its tag.
- A picked image is always copied into the cache directory before its path is reported.

## Negative Logic

- No image bytes on the stream. The host reports a path.
- No background speech. Utterances run while the program's activity is in front.
- No engine restart on failure. An engine that cannot start answers pending utterances with `0`.

## Dependencies and consumers

Depends on TextToSpeech, the ACTION_VIEW and ACTION_GET_CONTENT intents, the activity result and resume path of [[PuduActivity]], and the cache directory of the app. Called by [[PuduBridge]]. Its counterpart on iOS is [[pudu-ios-media]]. Program side: [[Std Mobile Media]].

## Resolved Grill Log

- **Q:** Why does BROWSED wait for the activity to resume? **A:** The browser is a separate activity. The program's page is shown again only when it returns, so that moment is the close the program waits for.
- **Q:** Why are utterances held until the engine is ready? **A:** The engine starts asynchronously. Dropping a speech request made before it was ready would release the tag with a false answer for a phrase that was never tried.
- **Q:** Why is the picked image copied to the cache directory? **A:** The provider's URI is valid only while the picker's grant lasts. The copy gives the program a path it can read after the grant ends.

## Referenced by

[[src/android/org/pudu/_MOC]] · [[PuduBridge]] · [[PuduActivity]] · [[pudu-android-services]] · [[pudu-ios-media]] · [[Std Mobile Media]] · [[NATIVE-MOBILE]]
