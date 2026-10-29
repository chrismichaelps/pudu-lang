/* Window state the platform changes on its own, reported as input records,
   and the settings a caller requests: density, size limits, aspect ratio and
   full screen. */
#import "pudu_desktop.h"
#import "pudu_desktop_host.h"

#include <float.h>

@implementation PuduWindowHost (WindowState)

- (void)recordScale {
  CGFloat scale = self.window.backingScaleFactor;
  if (scale == self.reportedScale) {
    return;
  }
  self.reportedScale = scale;
  [self record:[NSString stringWithFormat:@"scale\t%ld", lround(scale * 1000.0)]];
}

- (void)windowDidChangeBackingProperties:(NSNotification *)notification {
  (void)notification;
  [self recordScale];
}

- (void)windowDidBecomeKey:(NSNotification *)notification {
  (void)notification;
  [self record:@"focus\t1"];
}

- (void)windowDidResignKey:(NSNotification *)notification {
  (void)notification;
  [self record:@"focus\t0"];
}

- (void)windowDidMiniaturize:(NSNotification *)notification {
  (void)notification;
  [self record:@"minimize\t1"];
}

- (void)windowDidDeminiaturize:(NSNotification *)notification {
  (void)notification;
  [self record:@"minimize\t0"];
}

- (void)windowDidEnterFullScreen:(NSNotification *)notification {
  (void)notification;
  [self record:@"fullscreen\t1"];
}

- (void)windowDidExitFullScreen:(NSNotification *)notification {
  (void)notification;
  [self record:@"fullscreen\t0"];
}

@end

int32_t pudu_desktop_configure(
    void *handle,
    int32_t density,
    int32_t min_width,
    int32_t min_height,
    int32_t max_width,
    int32_t max_height,
    int32_t aspect_width,
    int32_t aspect_height,
    int32_t fullscreen) {
  if (![NSThread isMainThread]) {
    return -2;
  }
  if (handle == NULL || density < 250 || density > 8000 ||
      min_width < 0 || min_height < 0 || max_width < 0 || max_height < 0 ||
      (max_width > 0 && min_width > max_width) ||
      (max_height > 0 && min_height > max_height) ||
      aspect_width < 0 || aspect_height < 0 ||
      (aspect_width == 0) != (aspect_height == 0) ||
      (fullscreen != 0 && fullscreen != 1)) {
    return -1;
  }

  @autoreleasepool {
    @try {
      PuduWindowHost *host = (__bridge PuduWindowHost *)handle;
      NSWindow *window = host.window;
      host.density = density / 1000.0;
      window.contentMinSize = NSMakeSize(min_width, min_height);
      window.contentMaxSize = NSMakeSize(
          max_width > 0 ? max_width : FLT_MAX,
          max_height > 0 ? max_height : FLT_MAX);
      if (aspect_width > 0) {
        window.contentAspectRatio = NSMakeSize(aspect_width, aspect_height);
      } else {
        window.contentResizeIncrements = NSMakeSize(1, 1);
      }
      BOOL full = (window.styleMask & NSWindowStyleMaskFullScreen) != 0;
      if (full != (fullscreen == 1)) {
        [window toggleFullScreen:nil];
      }
      return 0;
    } @catch (NSException *exception) {
      (void)exception;
      return -4;
    }
  }
}
