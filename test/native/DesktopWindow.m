#import "pudu_desktop.h"
#import "pudu_desktop_host.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static void require(BOOL condition, const char *message) {
  if (!condition) {
    fprintf(stderr, "desktop window: %s\n", message);
    exit(1);
  }
}

static NSString *drain(void *handle) {
  int64_t held = pudu_desktop_inputs(handle, NULL, 0);
  require(held >= 0, "measure inputs");
  if (held == 0) {
    return @"";
  }
  uint8_t *buffer = malloc((size_t)held);
  require(buffer != NULL, "allocate inputs");
  require(pudu_desktop_inputs(handle, buffer, (size_t)held) == held, "copy inputs");
  NSString *text = [[NSString alloc] initWithBytes:buffer length:(NSUInteger)held encoding:NSUTF8StringEncoding];
  free(buffer);
  return text;
}

static BOOL awaitRecord(void *handle, NSString *line) {
  NSMutableString *seen = [NSMutableString string];
  for (int attempt = 0; attempt < 50; ++attempt) {
    pudu_desktop_pump(handle, 100);
    [seen appendString:drain(handle)];
    if ([[seen componentsSeparatedByString:@"\n"] containsObject:line]) {
      return YES;
    }
  }
  fprintf(stderr, "records seen: %s\n", seen.UTF8String);
  return NO;
}

static int32_t configure(void *handle, int32_t density, int32_t minW, int32_t minH, int32_t maxW,
    int32_t maxH, int32_t aspectW, int32_t aspectH, int32_t full) {
  return pudu_desktop_configure(handle, density, minW, minH, maxW, maxH, aspectW, aspectH, full);
}

int main(void) {
  @autoreleasepool {
    const char *title = "Window test";
    void *handle = pudu_desktop_open((const uint8_t *)title, strlen(title), 400, 300, 1);
    require(handle != NULL, "open");
    PuduWindowHost *host = (__bridge PuduWindowHost *)handle;
    NSWindow *window = host.window;
    pudu_desktop_pump(handle, 50);
    NSArray<NSString *> *opened = [drain(handle) componentsSeparatedByString:@"\n"];
    NSString *scale = [NSString stringWithFormat:@"scale\t%ld", lround(window.backingScaleFactor * 1000.0)];
    require([opened containsObject:scale], "scale recorded at open");
    require([[opened filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"SELF BEGINSWITH 'scale'"]] count] == 1, "scale recorded once");

    require(configure(handle, 249, 0, 0, 0, 0, 0, 0, 0) == -1, "density below range");
    require(configure(handle, 8001, 0, 0, 0, 0, 0, 0, 0) == -1, "density above range");
    require(configure(handle, 1000, -1, 0, 0, 0, 0, 0, 0) == -1, "negative minimum");
    require(configure(handle, 1000, 0, 0, 0, -1, 0, 0, 0) == -1, "negative maximum");
    require(configure(handle, 1000, 500, 0, 400, 0, 0, 0, 0) == -1, "minimum above maximum");
    require(configure(handle, 1000, 0, 0, 0, 0, 16, 0, 0) == -1, "half aspect");
    require(configure(handle, 1000, 0, 0, 0, 0, 0, 0, 2) == -1, "full screen is a flag");
    require(configure(NULL, 1000, 0, 0, 0, 0, 0, 0, 0) == -1, "null handle");
    require(host.density == 1.0, "refusal leaves density");

    require(configure(handle, 2000, 200, 100, 800, 600, 16, 9, 0) == 0, "configure");
    require(NSEqualSizes(window.contentMinSize, NSMakeSize(200, 100)), "minimum size");
    require(NSEqualSizes(window.contentMaxSize, NSMakeSize(800, 600)), "maximum size");
    require(NSEqualSizes(window.contentAspectRatio, NSMakeSize(16, 9)), "aspect ratio");

    size_t sharpLength = 640 * 360 * 4;
    uint8_t *sharp = calloc(sharpLength, 1);
    require(sharp != NULL, "allocate frame");
    require(pudu_desktop_present(handle, 640, 360, sharp, sharpLength) == 0, "present at density 2000");
    require(NSEqualSizes([window contentRectForFrameRect:window.frame].size, NSMakeSize(320, 180)), "density divides frame pixels into points");
    free(sharp);

    require(configure(handle, 1000, 0, 0, 0, 0, 0, 0, 0) == 0, "reset");
    require(NSEqualSizes(window.contentAspectRatio, NSZeroSize), "aspect cleared");
    size_t plainLength = 300 * 200 * 4;
    uint8_t *plain = calloc(plainLength, 1);
    require(plain != NULL, "allocate frame");
    require(pudu_desktop_present(handle, 300, 200, plain, plainLength) == 0, "present at density 1000");
    require(NSEqualSizes([window contentRectForFrameRect:window.frame].size, NSMakeSize(300, 200)), "one-to-one density keeps pixel size");
    free(plain);

    if (getenv("PUDU_LIVE_DESKTOP") != NULL) {
      require([opened containsObject:@"focus\t1"] || awaitRecord(handle, @"focus\t1"), "focus recorded");
      drain(handle);
      [window miniaturize:nil];
      require(awaitRecord(handle, @"minimize\t1"), "minimize recorded");
      [window deminiaturize:nil];
      require(awaitRecord(handle, @"minimize\t0"), "restore recorded");
      require(configure(handle, 1000, 0, 0, 0, 0, 0, 0, 1) == 0, "request full screen");
      require(awaitRecord(handle, @"fullscreen\t1"), "full screen recorded");
      require(configure(handle, 1000, 0, 0, 0, 0, 0, 0, 0) == 0, "leave full screen");
      require(awaitRecord(handle, @"fullscreen\t0"), "windowed recorded");
    }
    require(pudu_desktop_close(handle) == 0, "close");
  }
  puts("desktop window: ok");
  return 0;
}
