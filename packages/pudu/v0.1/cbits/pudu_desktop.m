#import "pudu_desktop.h"

#import <AppKit/AppKit.h>
#import <CoreGraphics/CoreGraphics.h>

@interface PuduFrameView : NSView
@property(nonatomic, strong) NSData *rgba;
@property(nonatomic) NSInteger pixelWidth;
@property(nonatomic) NSInteger pixelHeight;
@end

@implementation PuduFrameView

- (BOOL)isOpaque {
  return YES;
}

- (void)drawRect:(NSRect)dirtyRect {
  [super drawRect:dirtyRect];
  NSData *frame = self.rgba;
  if (frame == nil || self.pixelWidth <= 0 || self.pixelHeight <= 0) {
    [[NSColor blackColor] setFill];
    NSRectFill(dirtyRect);
    return;
  }

  CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
  CGDataProviderRef provider = CGDataProviderCreateWithCFData((__bridge CFDataRef)frame);
  CGImageRef image = CGImageCreate(
      (size_t)self.pixelWidth,
      (size_t)self.pixelHeight,
      8,
      32,
      (size_t)self.pixelWidth * 4,
      colorSpace,
      kCGBitmapByteOrderDefault | kCGImageAlphaLast,
      provider,
      NULL,
      false,
      kCGRenderingIntentDefault);

  CGContextRef context = [[NSGraphicsContext currentContext] CGContext];
  CGContextSaveGState(context);
  CGContextSetInterpolationQuality(context, kCGInterpolationNone);
  CGContextTranslateCTM(context, 0, NSHeight(self.bounds));
  CGContextScaleCTM(context, 1, -1);
  CGContextDrawImage(context, NSMakeRect(0, 0, NSWidth(self.bounds), NSHeight(self.bounds)), image);
  CGContextRestoreGState(context);

  CGImageRelease(image);
  CGDataProviderRelease(provider);
  CGColorSpaceRelease(colorSpace);
}

@end

@interface PuduWindowHost : NSObject <NSWindowDelegate>
@property(nonatomic, strong) NSWindow *window;
@property(nonatomic, strong) PuduFrameView *frameView;
@property(nonatomic) BOOL closeRequested;
@end

@implementation PuduWindowHost

- (BOOL)windowShouldClose:(NSWindow *)sender {
  (void)sender;
  self.closeRequested = YES;
  return NO;
}

@end

static BOOL pudu_on_main_thread(void) {
  return [NSThread isMainThread];
}

void *pudu_desktop_open(
    const uint8_t *title,
    size_t title_length,
    int32_t width,
    int32_t height,
    int32_t resizable) {
  if (!pudu_on_main_thread() || title == NULL || title_length == 0 ||
      width <= 0 || height <= 0) {
    return NULL;
  }

  @autoreleasepool {
    @try {
      NSString *caption = [[NSString alloc]
          initWithBytes:title
                 length:title_length
               encoding:NSUTF8StringEncoding];
      if (caption == nil || caption.length == 0) {
        return NULL;
      }

      NSApplication *application = [NSApplication sharedApplication];
      [application setActivationPolicy:NSApplicationActivationPolicyRegular];
      if (!application.isRunning) {
        [application finishLaunching];
      }

      NSWindowStyleMask style = NSWindowStyleMaskTitled |
          NSWindowStyleMaskClosable |
          NSWindowStyleMaskMiniaturizable;
      if (resizable != 0) {
        style |= NSWindowStyleMaskResizable;
      }

      NSWindow *window = [[NSWindow alloc]
          initWithContentRect:NSMakeRect(0, 0, width, height)
                    styleMask:style
                      backing:NSBackingStoreBuffered
                        defer:NO];
      if (window == nil) {
        return NULL;
      }

      PuduFrameView *view = [[PuduFrameView alloc]
          initWithFrame:NSMakeRect(0, 0, width, height)];
      PuduWindowHost *host = [[PuduWindowHost alloc] init];
      host.window = window;
      host.frameView = view;
      window.delegate = host;
      window.title = caption;
      window.releasedWhenClosed = NO;
      window.contentView = view;
      [window center];
      [window makeKeyAndOrderFront:nil];
      [application activateIgnoringOtherApps:YES];
      return (__bridge_retained void *)host;
    } @catch (NSException *exception) {
      (void)exception;
      return NULL;
    }
  }
}

int32_t pudu_desktop_present(
    void *handle,
    int32_t width,
    int32_t height,
    const uint8_t *rgba,
    size_t rgba_length) {
  if (!pudu_on_main_thread()) {
    return -2;
  }
  if (handle == NULL || rgba == NULL || width <= 0 || height <= 0) {
    return -1;
  }
  size_t expected = (size_t)width * (size_t)height * 4;
  if (rgba_length != expected) {
    return -3;
  }

  @autoreleasepool {
    @try {
      PuduWindowHost *host = (__bridge PuduWindowHost *)handle;
      host.frameView.rgba = [NSData dataWithBytes:rgba length:rgba_length];
      host.frameView.pixelWidth = width;
      host.frameView.pixelHeight = height;
      [host.window setContentSize:NSMakeSize(width, height)];
      [host.frameView setNeedsDisplay:YES];
      [host.frameView displayIfNeeded];
      return 0;
    } @catch (NSException *exception) {
      (void)exception;
      return -4;
    }
  }
}

int32_t pudu_desktop_pump(void *handle, int32_t milliseconds) {
  if (!pudu_on_main_thread()) {
    return -2;
  }
  if (handle == NULL || milliseconds < 0) {
    return -1;
  }

  @autoreleasepool {
    @try {
      PuduWindowHost *host = (__bridge PuduWindowHost *)handle;
      NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:((double)milliseconds / 1000.0)];
      NSApplication *application = [NSApplication sharedApplication];
      while (!host.closeRequested) {
        NSEvent *event = [application
            nextEventMatchingMask:NSEventMaskAny
                        untilDate:deadline
                           inMode:NSDefaultRunLoopMode
                          dequeue:YES];
        if (event == nil) {
          break;
        }
        [application sendEvent:event];
        [application updateWindows];
      }
      [host.frameView displayIfNeeded];
      return host.closeRequested ? 1 : 0;
    } @catch (NSException *exception) {
      (void)exception;
      return -4;
    }
  }
}

int32_t pudu_desktop_close(void *handle) {
  if (!pudu_on_main_thread()) {
    return -2;
  }
  if (handle == NULL) {
    return -1;
  }

  @autoreleasepool {
    @try {
      PuduWindowHost *host = (__bridge_transfer PuduWindowHost *)handle;
      host.window.delegate = nil;
      [host.window orderOut:nil];
      [host.window close];
      host.frameView.rgba = nil;
      host.frameView = nil;
      host.window = nil;
      return 0;
    } @catch (NSException *exception) {
      (void)exception;
      return -4;
    }
  }
}
