#ifndef PUDU_IOS_IMAGE_H
#define PUDU_IOS_IMAGE_H

/* Images from the application's assets and from the network. A source is
   decoded off the main thread straight to the pixel size the view can show,
   so a large file never reaches the screen or the memory cache at full size.
   Decoded images are kept in a cache bounded by bytes and emptied when the
   platform is short of memory; remote bytes go through a URL session whose
   protocol cache revalidates them. A view that is given a new source cancels
   its load in flight, and an answer for a source the view no longer shows is
   dropped, so a reused view never shows another source's image. Each source
   set reports IMAGED once: 1 when it is shown, 0 when it could not be. */
#import <ImageIO/ImageIO.h>
#import <UIKit/UIKit.h>
#include <stdint.h>
#include <stdio.h>
#include "pudu_ios_events.h"

enum { PUDU_IMAGE_ORIGINS = 2, PUDU_IMAGE_SCALINGS = 3 };
/* Decoded images held at most, in bytes. */
static const NSUInteger PUDU_IMAGE_CACHE_BYTES = 64u * 1024u * 1024u;
/* The most bytes one remote source may have; a larger one stops while it downloads. */
static const long long PUDU_IMAGE_MAX_BYTES = 32LL * 1024 * 1024;

/* One remote download: its bytes so far, stopped past the byte limit, and
   what to do with the bytes or the failure (nil) once it ends. */
@interface PuduImageLoad : NSObject <NSURLSessionDataDelegate>
@property (strong, nonatomic) NSMutableData *bytes;
@property (copy, nonatomic) void (^finished)(NSData *bytes);
@end
@implementation PuduImageLoad
- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)task didReceiveResponse:(NSURLResponse *)response
 completionHandler:(void (^)(NSURLSessionResponseDisposition))answer {
  (void)session;
  (void)task;
  NSInteger status = [response isKindOfClass:NSHTTPURLResponse.class] ? ((NSHTTPURLResponse *)response).statusCode : 0;
  BOOL wanted = status >= 200 && status < 300 && response.expectedContentLength <= PUDU_IMAGE_MAX_BYTES;
  self.bytes = [NSMutableData new];
  answer(wanted ? NSURLSessionResponseAllow : NSURLSessionResponseCancel);
  if (!wanted) self.bytes = nil;
}
- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)task didReceiveData:(NSData *)data {
  (void)session;
  if (self.bytes == nil) return;
  if ((long long)self.bytes.length + (long long)data.length > PUDU_IMAGE_MAX_BYTES) {
    self.bytes = nil;
    [task cancel];
    return;
  }
  [self.bytes appendData:data];
}
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error {
  (void)session;
  (void)task;
  /* A load the view cancelled for a new source reports nothing. */
  if (error.code == NSURLErrorCancelled && self.bytes != nil) return;
  self.finished(error == nil ? self.bytes : nil);
}
@end

/* An image view and the source it shows: `key` names the source at the
   pixel size it was decoded for; `loaded` is what the last report said. */
@interface PuduImage : UIImageView
@property (copy, nonatomic) NSString *key;
@property (strong, nonatomic) NSURLSessionDataTask *task;
@property (nonatomic) int loaded;
@end
@implementation PuduImage
@end

static NSCache<NSString *, UIImage *> *pudu_image_cache;
static NSURLSession *pudu_image_session;
static dispatch_queue_t pudu_image_queue;

static void pudu_image_start(void) {
  if (pudu_image_cache != nil) return;
  pudu_image_cache = [NSCache new];
  pudu_image_cache.totalCostLimit = PUDU_IMAGE_CACHE_BYTES;
  NSURLSessionConfiguration *configuration = NSURLSessionConfiguration.defaultSessionConfiguration;
  configuration.requestCachePolicy = NSURLRequestUseProtocolCachePolicy;
  configuration.URLCache = [[NSURLCache alloc] initWithMemoryCapacity:8u * 1024u * 1024u diskCapacity:128u * 1024u * 1024u directoryURL:nil];
  configuration.timeoutIntervalForRequest = 30;
  configuration.timeoutIntervalForResource = 60;
  pudu_image_session = [NSURLSession sessionWithConfiguration:configuration];
  pudu_image_queue = dispatch_queue_create("org.pudu.image", DISPATCH_QUEUE_CONCURRENT);
  [NSNotificationCenter.defaultCenter addObserverForName:UIApplicationDidReceiveMemoryWarningNotification object:nil
                                                   queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *note) {
    (void)note;
    [pudu_image_cache removeAllObjects];
  }];
}

static UIView *pudu_make_image(void) {
  PuduImage *image = [PuduImage new];
  image.clipsToBounds = YES;
  image.loaded = -1;
  return image;
}

/* The longest side the view can show, in pixels, rounded up to a power of two
   so neighbouring sizes share one decoded image; the screen's longest side
   before the view is laid out. */
static NSUInteger pudu_image_pixels(UIView *view) {
  CGFloat scale = UIScreen.mainScreen.scale;
  CGSize size = view.bounds.size;
  CGFloat longest = MAX(size.width, size.height);
  if (longest <= 0) longest = MAX(UIScreen.mainScreen.bounds.size.width, UIScreen.mainScreen.bounds.size.height);
  NSUInteger wanted = (NSUInteger)ceil(longest * scale), bucket = 64;
  while (bucket < wanted) bucket *= 2;
  return bucket;
}

/* A decoded image no longer than `pixels` on its longest side, or nil. */
static UIImage *pudu_image_decode(CGImageSourceRef source, NSUInteger pixels) {
  if (source == NULL) return nil;
  NSDictionary *options = @{
    (id)kCGImageSourceCreateThumbnailFromImageAlways : @YES,
    (id)kCGImageSourceCreateThumbnailWithTransform : @YES,
    (id)kCGImageSourceShouldCacheImmediately : @YES,
    (id)kCGImageSourceThumbnailMaxPixelSize : @(pixels),
  };
  CGImageRef decoded = CGImageSourceCreateThumbnailAtIndex(source, 0, (__bridge CFDictionaryRef)options);
  CFRelease(source);
  if (decoded == NULL) return nil;
  UIImage *image = [UIImage imageWithCGImage:decoded scale:UIScreen.mainScreen.scale orientation:UIImageOrientationUp];
  CGImageRelease(decoded);
  return image;
}

/* Shows `image` (nil for a failure) if the view still shows `key`, caches it,
   and reports. */
static void pudu_image_land(PuduImage *view, NSString *key, UIImage *image) {
  if (![view.key isEqualToString:key]) return;
  view.task = nil;
  if (image != nil) {
    CGImageRef pixels = image.CGImage;
    [pudu_image_cache setObject:image forKey:key cost:CGImageGetBytesPerRow(pixels) * CGImageGetHeight(pixels)];
  }
  view.image = image;
  view.loaded = image != nil;
  [view invalidateIntrinsicContentSize];
  pudu_queue(PUDU_UI_IMAGED, view.tag, nil, image != nil ? 1 : 0);
}

/* An asset's file, refused when its name leaves the assets directory. */
static NSURL *pudu_image_asset(NSString *name) {
  NSString *root = [NSBundle.mainBundle.resourcePath stringByAppendingPathComponent:@"assets"];
  if (name.length == 0 || [name hasPrefix:@"/"] || [name.pathComponents containsObject:@".."]) return nil;
  return [NSURL fileURLWithPath:[root stringByAppendingPathComponent:name]];
}

/* SOURCE on an image: cancels what it was loading and shows the new source,
   from the cache when it holds it. */
static void pudu_image_source(UIView *node, uint32_t origin, uint32_t scaling, NSString *location) {
  static const UIViewContentMode modes[PUDU_IMAGE_SCALINGS] = {
    UIViewContentModeScaleAspectFill, UIViewContentModeScaleAspectFit, UIViewContentModeScaleToFill };
  PuduImage *view = (PuduImage *)node;
  NSUInteger pixels = pudu_image_pixels(view);
  NSString *key = [NSString stringWithFormat:@"%u:%@@%lu", origin, location, (unsigned long)pixels];
  pudu_image_start();
  view.contentMode = modes[scaling];
  if ([view.key isEqualToString:key] && view.loaded >= 0) return;
  [view.task cancel];
  view.task = nil;
  view.key = key;
  view.loaded = -1;
  UIImage *cached = [pudu_image_cache objectForKey:key];
  if (cached != nil) {
    pudu_image_land(view, key, cached);
    return;
  }
  view.image = nil;
  if (origin == 0) {
    NSURL *file = pudu_image_asset(location);
    dispatch_async(pudu_image_queue, ^{
      UIImage *image = file == nil ? nil : pudu_image_decode(CGImageSourceCreateWithURL((__bridge CFURLRef)file, NULL), pixels);
      dispatch_async(dispatch_get_main_queue(), ^{ pudu_image_land(view, key, image); });
    });
    return;
  }
  NSURL *url = [NSURL URLWithString:location];
  if (url == nil || !([url.scheme isEqualToString:@"https"] || [url.scheme isEqualToString:@"http"])) {
    pudu_image_land(view, key, nil);
    return;
  }
  PuduImageLoad *load = [PuduImageLoad new];
  load.finished = ^(NSData *bytes) {
    dispatch_async(pudu_image_queue, ^{
      UIImage *image = bytes == nil ? nil : pudu_image_decode(CGImageSourceCreateWithData((__bridge CFDataRef)bytes, NULL), pixels);
      dispatch_async(dispatch_get_main_queue(), ^{ pudu_image_land(view, key, image); });
    });
  };
  view.task = [pudu_image_session dataTaskWithURL:url];
  view.task.delegate = load;
  [view.task resume];
}

/* The image self-test: waits until every image has reported, then prints each
   one's tag, whether it shows an image and its pixel size, in tag order. */
static void pudu_test_images(NSArray *nodes, void (^done)(void)) {
  NSMutableArray<PuduImage *> *images = [NSMutableArray new];
  for (id node in nodes) {
    if ([node isKindOfClass:PuduImage.class]) [images addObject:node];
  }
  [images sortUsingComparator:^NSComparisonResult(PuduImage *left, PuduImage *right) { return [@(left.tag) compare:@(right.tag)]; }];
  __block int waited = 0;
  __block void (^check)(void);
  void (^ready)(void) = ^{
    BOOL settled = YES;
    for (PuduImage *image in images) settled = settled && image.loaded >= 0;
    if (!settled && waited++ < 100) {
      dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 100 * NSEC_PER_MSEC), dispatch_get_main_queue(), check);
      return;
    }
    for (PuduImage *image in images) {
      CGImageRef pixels = image.image.CGImage;
      printf("PUDU_IMAGE %ld %d %zux%zu\n", (long)image.tag, image.loaded, pixels == NULL ? 0 : CGImageGetWidth(pixels),
             pixels == NULL ? 0 : CGImageGetHeight(pixels));
    }
    fflush(stdout);
    check = nil;
    done();
  };
  check = ready;
  check();
}

#endif
