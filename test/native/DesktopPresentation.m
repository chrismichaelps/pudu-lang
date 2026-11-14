#import "pudu_desktop_host.h"
#import <CoreGraphics/CoreGraphics.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static const uint8_t frame[] = {
    255, 0, 0, 255, 0, 255, 0, 255,
    0, 0, 255, 255, 255, 255, 0, 255,
    0, 255, 255, 255, 255, 0, 255, 255};

static void require(BOOL condition, const char *message) {
  if (!condition) {
    fprintf(stderr, "desktop presentation: %s\n", message);
    exit(1);
  }
}

static void check(NSInteger logicalScale, NSInteger deviceScale, BOOL empty) {
  NSInteger width = 2 * logicalScale;
  NSInteger height = 3 * logicalScale;
  NSInteger pixelsWide = width * deviceScale;
  NSInteger pixelsHigh = height * deviceScale;
  size_t stride = (size_t)pixelsWide * 4;
  uint8_t *pixels = calloc((size_t)pixelsHigh, stride);
  require(pixels != NULL, "allocate bitmap");
  CGColorSpaceRef colors = CGColorSpaceCreateDeviceRGB();
  CGContextRef context = CGBitmapContextCreate(pixels, (size_t)pixelsWide,
      (size_t)pixelsHigh, 8, stride, colors,
      kCGBitmapByteOrder32Big | kCGImageAlphaPremultipliedLast);
  require(context != NULL, "create bitmap context");
  CGContextScaleCTM(context, (CGFloat)deviceScale, (CGFloat)deviceScale);
  PuduFrameView *view = [[PuduFrameView alloc] initWithFrame:NSMakeRect(0, 0, width, height)];
  require(!view.isFlipped, "native view coordinate contract");
  if (!empty) {
    view.rgba = [NSData dataWithBytes:frame length:sizeof(frame)];
    view.pixelWidth = 2;
    view.pixelHeight = 3;
  }
  NSGraphicsContext *previous = [NSGraphicsContext currentContext];
  NSGraphicsContext *graphics = [NSGraphicsContext graphicsContextWithCGContext:context flipped:NO];
  [NSGraphicsContext setCurrentContext:graphics];
  [view drawRect:view.bounds];
  [NSGraphicsContext setCurrentContext:previous];
  CGContextFlush(context);
  const uint8_t black[] = {0, 0, 0, 255};
  for (NSInteger row = 0; row < pixelsHigh; ++row) {
    for (NSInteger column = 0; column < pixelsWide; ++column) {
      NSInteger source = ((row / (logicalScale * deviceScale)) * 2 +
          column / (logicalScale * deviceScale)) * 4;
      const uint8_t *expected = empty ? black : frame + source;
      const uint8_t *actual = pixels + (size_t)row * stride + (size_t)column * 4;
      if (memcmp(actual, expected, 4) != 0) {
        fprintf(stderr, "pixel (%ld,%ld): got %u,%u,%u,%u; expected %u,%u,%u,%u\n",
            (long)column, (long)row, actual[0], actual[1], actual[2], actual[3],
            expected[0], expected[1], expected[2], expected[3]);
        require(NO, "row/channel orientation");
      }
    }
  }
  graphics = nil;
  CGContextRelease(context);
  CGColorSpaceRelease(colors);
  free(pixels);
}

int main(void) {
  @autoreleasepool {
    check(1, 1, NO);
    check(2, 1, NO);
    check(1, 2, NO);
    check(1, 1, YES);
  }
  puts("desktop presentation: ok");
  return 0;
}
