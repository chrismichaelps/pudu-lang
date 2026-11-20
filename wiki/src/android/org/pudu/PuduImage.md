---
type: module
path: "@root/packages/pudu/v0.1/android/org/pudu/PuduImage.java"
fidelity: Active
subsystem: "[[Backend]]"
tags: [module, native, android, image, cache]
aliases: [PuduImage, Native Android Image]
---

# PuduImage

## Purpose and interface

Images on the Android host, from the application's assets and from the network. The class is called from [[PuduBridge]] when a kind 22 node is created and when a SOURCE 45 instruction arrives for it, and from the memory callbacks of [[PuduActivity]]. A source is decoded on a worker thread to the largest power-of-two sample size that still covers the view's pixel size. The report is IMAGED (24) of [[Std Mobile Events]], sent through [[PuduBridge]].

```java
final class PuduImage
static final int IMAGED = 24;
static ImageView make()
static void source(ImageView view, int origin, int scaling, String location)
static void trim()
```

## Behavior

- `make` creates an `ImageView` with adjusted bounds and registers it with an empty shown record.
- `source` maps the scaling code to a scale type: 0 center crop, 1 fit center, 2 fit XY. The key is the origin, the location and the pixel size. A key equal to the one shown changes nothing.
- A new key cancels the load in flight for the view, clears the image, and either lands a cached bitmap at once or submits a load to the worker pool.
- The worker pool is a fixed pool of three threads, created on first use.
- A load reads the bytes: an asset through the application's asset manager, a URL through `HttpURLConnection` with the platform response cache installed by [[PuduFetch]]. A non-http or https URL, a status outside 200 to 299, or an exception yields no bitmap.
- Decoding reads the bounds first. The sample size doubles while the longest side divided by twice the sample size is still at least the pixel size. The decoded longest side therefore stays at least the view's pixel size.
- The pixel size is the view's longest side in pixels rounded up to a power of two from 64. Before layout, the screen's longest side is used.
- The cache is an `LruCache` sized at one eighth of the maximum heap, charged by each bitmap's allocation byte count.
- `trim` empties the cache. [[PuduActivity]] calls it from `onTrimMemory` and `onLowMemory`.
- `land` drops an answer whose key is no longer shown. Otherwise it caches a bitmap, sets it on the view, and sends IMAGED with 1 when a bitmap was shown and 0 when none was.

## Invariants

- A view shows only the source its shown record names. The key is compared on the main thread after the worker posts the answer.
- IMAGED is sent once per source set, from `land`, and only for the key still shown.
- The cache is touched on the main thread except for the cache lookup and the bitmap put, which the `LruCache` synchronizes.

## Negative Logic

- No placeholder drawable while loading.
- No retry of a failed load. A failure is reported as 0.
- No read of a path outside the assets. A name that starts with a slash or contains a `..` segment yields no bytes.
- No decode at full size. A file is decoded at the sample size the view needs, never larger.
- No memory held for a view after it is collected; the shown record is in a weak map.

## Dependencies and consumers

Depends on `android.graphics.BitmapFactory`, `android.util.LruCache`, `android.widget.ImageView`, the application's asset manager, `HttpURLConnection` and the response cache installed by [[PuduFetch]]. Called by [[PuduBridge]] and [[PuduActivity]]. The iOS counterpart is [[pudu-ios-image]]. Asset packaging: [[Backend Toolchain Assets]], which stages the files this class reads.

## Resolved Grill Log

- **Q:** Why a power-of-two sample size rather than an exact scale? **A:** BitmapFactory decodes at integer powers of two cheaply. The rule keeps the decoded longest side at or above the view's pixel size, so the image is sharp at the size it is shown.
- **Q:** Why an eighth of the heap for the cache? **A:** It is the share the platform's own image caches use. A fixed byte size would be too large on small devices and too small on large ones.
- **Q:** Why three workers? **A:** Image requests come from the visible part of a screen. Three keeps several decodes moving without holding a thread per request.
- **Q:** Why the platform response cache for remote bytes? **A:** The cache already implements validators and freshness. A second cache would duplicate them, as [[PuduFetch]] also reasons.
- **Q:** Why cancel the load and also check the key? **A:** Cancelling stops the transfer when it can be stopped. A worker that has already read its bytes cannot be interrupted, so the key check drops its answer.

## Referenced by

[[src/_MOC]] · [[PuduFetch]] · [[PuduBridge]] · [[PuduActivity]] · [[pudu-ios-image]] · [[Native Images Delivery]] · [[NATIVE-MOBILE]]
