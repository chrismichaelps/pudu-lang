---
type: module
path: "@root/packages/pudu/v0.1/cbits/pudu_ios_image.h"
fidelity: Active
domain: "[[Pudu Native]]"
subsystem: "[[Native Mobile Targets]]"
tags: [module, host, ios, native, image, objective-c]
aliases: [iOS Host Images, pudu-ios-image]
---

# pudu-ios-image

## Purpose and interface

Images of the iOS host, from the application's assets and from the network. Included once by [[iOS Host Adapter]]. The compiler stages it with the other private headers ([[Native Toolchain Host Sources]]). It owns the image view, its source key and its load task; the decoder and the caches; and the self-test. It implements kind 22 (IMAGE) and the handler of instruction SOURCE (45) of [[Std Mobile Stream]]. Its report is IMAGED (24) of [[Std Mobile Events]], queued through [[iOS Host Events]]. The kind table that names these hooks is [[pudu-ios-kinds]]. ImageIO is linked by the application build.

```text
@interface PuduImage : UIImageView   key, task, loaded
static void pudu_image_source(UIView *node, uint32_t origin, uint32_t scaling, NSString *location)
static void pudu_test_images(NSArray *nodes, void (^done)(void))
```

## Behavior

- CREATE 22 makes a `PuduImage` with `loaded` at -1, so no report has been made for it yet. Its clipping is on.
- SOURCE 45 names the node, the origin (0 an asset name, 1 a URL), the scaling and the location text. Origin 0 is read from the application's `assets` directory in the bundle; origin 1 is a URL.
- Scalings: Fill sets aspect fill, which covers the view and clips the rest; Fit sets aspect fit; Stretch sets scale to fill.
- The source key is the origin, the location and the pixel size, so one source at two sizes is two entries.
- Decoding runs on a concurrent queue. `CGImageSourceCreateThumbnailAtIndex` with a maximum pixel size produces the decoded image directly at the view's size, transformed to its orientation.
- The pixel size is the view's longest side in points times the screen scale, rounded up to a power of two starting at 64. Before layout, the screen's longest side is used.
- The decoded images are held in an `NSCache` bounded at 64 MB by decoded bytes. A memory warning empties it.
- Remote bytes use an `NSURLSession` with the protocol cache policy and an `NSURLCache` of 8 MB in memory and 128 MB on disk.
- A new source cancels the task in flight. An answer for a key the view no longer shows is dropped.
- A location that leaves the assets directory (an empty name, a leading slash or a `..` segment) reports a failure. A URL that is not http or https reports a failure.
- A response with a status outside 200 to 299, or a transport error, reports a failure. A cancelled task reports nothing.
- Every answer, success or failure, reports IMAGED once for that source: 1 when the image is shown, 0 when it could not be.

Refusals, reported as SOURCE defects through the same path as [[pudu_ios_refresh.h]]: a node that is not an image, an origin of 2 or more, and a scaling of 3 or more.

Self-test: `PUDU_UI_IMAGE_TEST` waits until every image in the tree has reported, for at most about 10 seconds, then prints one line per image in tag order: `PUDU_IMAGE <tag> <loaded> <w>x<h>`. An image with no decoded bitmap prints `0x0`.

## Invariants

- A view shows only the source its key names. A stale answer is dropped by comparing the key on the main thread.
- A source set reports IMAGED exactly once. The `loaded` field is set before the report, so the self-test sees the final state.
- A decoded image is never larger on its longest side than the power-of-two bucket of the view's pixel size, unless the source itself is smaller.
- Cache entries are charged by their decoded byte size, so the 64 MB bound is in memory, not in entries.

## Negative Logic

- No full-size decode. A file larger than the view is never held at its file size in the cache.
- No retry. A failed load reports 0; the program decides whether to send the source again.
- No placeholder image. While loading, the view shows nothing.
- No write to the assets directory and no access outside it.
- No image report for a node that is not an image.

## Dependencies and consumers

Depends on UIKit, ImageIO, Foundation's URL session, [[iOS Host Events]] for the IMAGED queue, [[pudu_ios_nodes.h]] for the node table, and [[pudu-ios-kinds]] for the kind entry. Included by [[iOS Host Adapter]]. Program side: [[Std Mobile Control]], [[Std Mobile Stream]] and [[Std Mobile Events]]. Asset packaging: [[Backend Toolchain Assets]].

## Resolved Grill Log

- **Q:** Why decode at the view's pixel size rather than the file's size? **A:** A photo can be far larger than the screen. Decoding at full size costs memory the view can never show. The thumbnail call decodes straight to the target size, so the full bitmap is never built.
- **Q:** Why round the size up to a power of two? **A:** A view that resizes by a few points would otherwise decode again for every size. Power-of-two buckets let neighbouring sizes share one cached image.
- **Q:** Why is the size taken before layout? **A:** A view created before layout has no bounds. The screen's longest side is a safe upper bound, and the next layout's larger need starts a new decode under a new key.
- **Q:** Why cancel the task rather than let it finish and drop the answer? **A:** A reused view under fast scrolling would otherwise keep several downloads alive for sources it no longer shows. Cancelling frees the connection; the key check still guards any answer that races the cancel.
- **Q:** Why 64 MB for the decoded cache? **A:** It holds a screenful of large images without letting a long list grow memory without bound. The memory warning empties it when the system asks.

## Referenced by

[[src/cbits/_MOC]] · [[iOS Host Adapter]] · [[pudu-ios-kinds]] · [[Std Mobile Control]] · [[Std Mobile Stream]] · [[Std Mobile Events]] · [[Backend Toolchain Assets]] · [[Native Images Delivery]] · [[Gallery Example]]
