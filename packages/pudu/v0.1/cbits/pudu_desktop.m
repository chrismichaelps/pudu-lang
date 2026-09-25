#import "pudu_desktop.h"

#import <AppKit/AppKit.h>
#import <CoreGraphics/CoreGraphics.h>

/* Queued input past this many bytes is dropped until the program drains. */
#define PUDU_INPUT_LIMIT ((NSUInteger)1 << 20)

/* Virtual key codes named by what they do on a screen. */
enum {
  PuduKeyReturn = 36,
  PuduKeyTab = 48,
  PuduKeyDelete = 51,
  PuduKeyEscape = 53,
  PuduKeyEnter = 76
};

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
@property(nonatomic, strong) NSMutableData *inputs;
@end

@implementation PuduWindowHost

- (void)windowDidResize:(NSNotification *)notification {
  (void)notification;
  NSSize size = self.frameView.bounds.size;
  [self record:[NSString stringWithFormat:@"resize\t%ld\t%ld",
      (long)size.width, (long)size.height]];
}

- (void)record:(NSString *)line {
  if (self.inputs.length > PUDU_INPUT_LIMIT) {
    return;
  }
  [self.inputs appendData:[line dataUsingEncoding:NSUTF8StringEncoding]];
  [self.inputs appendBytes:"\n" length:1];
}

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
      host.inputs = [NSMutableData data];
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

static NSString *pudu_key_name(NSEvent *event) {
  BOOL shifted = (event.modifierFlags & NSEventModifierFlagShift) != 0;
  switch (event.keyCode) {
    case PuduKeyTab: return shifted ? @"previous" : @"next";
    case PuduKeyReturn:
    case PuduKeyEnter: return @"activate";
    case PuduKeyEscape: return @"dismiss";
    case PuduKeyDelete: return @"erase";
    default: return nil;
  }
}

static NSString *pudu_chord(NSEvent *event) {
  NSEventModifierFlags flags = event.modifierFlags;
  NSString *key = event.charactersIgnoringModifiers.lowercaseString;
  if (key.length == 0) {
    return nil;
  }
  NSMutableString *chord = [NSMutableString string];
  if (flags & NSEventModifierFlagCommand) [chord appendString:@"cmd+"];
  if (flags & NSEventModifierFlagControl) [chord appendString:@"ctrl+"];
  if (flags & NSEventModifierFlagOption) [chord appendString:@"alt+"];
  if (flags & NSEventModifierFlagShift) [chord appendString:@"shift+"];
  [chord appendString:key];
  return chord;
}

static NSString *pudu_printable(NSString *characters) {
  NSMutableString *kept = [NSMutableString string];
  [characters enumerateSubstringsInRange:NSMakeRange(0, characters.length)
                                 options:NSStringEnumerationByComposedCharacterSequences
                              usingBlock:^(NSString *piece, NSRange range, NSRange enclosing, BOOL *stop) {
    (void)range; (void)enclosing; (void)stop;
    unichar first = [piece characterAtIndex:0];
    if (first >= 0x20 && first != 0x7f && (first < 0xf700 || first > 0xf8ff)) {
      [kept appendString:piece];
    }
  }];
  return kept;
}

/* Records what a person did in the host's window. Answers whether the
   event was consumed, so key presses never reach AppKit's responder chain,
   which would answer an unhandled key with the system alert sound. */
static BOOL pudu_record_input(PuduWindowHost *host, NSEvent *event) {
  if (event.window != host.window) {
    return NO;
  }
  NSPoint location = event.locationInWindow;
  long x = (long)location.x;
  long y = (long)(NSHeight(host.frameView.bounds) - location.y);
  switch (event.type) {
    case NSEventTypeLeftMouseDown:
      [host record:[NSString stringWithFormat:@"press\t%ld\t%ld", x, y]];
      return NO;
    case NSEventTypeScrollWheel: {
      long delta = (long)event.scrollingDeltaY;
      if (delta != 0) {
        [host record:[NSString stringWithFormat:@"scroll\t%ld\t%ld\t%ld", x, y, -delta]];
      }
      return NO;
    }
    case NSEventTypeKeyDown: {
      NSEventModifierFlags flags = event.modifierFlags;
      if (flags & (NSEventModifierFlagCommand | NSEventModifierFlagControl)) {
        NSString *chord = pudu_chord(event);
        if (chord != nil) {
          [host record:[@"chord\t" stringByAppendingString:chord]];
        }
        return YES;
      }
      NSString *name = pudu_key_name(event);
      if (name != nil) {
        [host record:[@"key\t" stringByAppendingString:name]];
        return YES;
      }
      NSString *text = pudu_printable(event.characters);
      if (text.length > 0) {
        [host record:[@"text\t" stringByAppendingString:text]];
      }
      return YES;
    }
    default:
      return NO;
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
        if (pudu_record_input(host, event)) {
          continue;
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

int64_t pudu_desktop_inputs(void *handle, uint8_t *buffer, size_t capacity) {
  if (!pudu_on_main_thread()) {
    return -2;
  }
  if (handle == NULL) {
    return -1;
  }
  @autoreleasepool {
    PuduWindowHost *host = (__bridge PuduWindowHost *)handle;
    NSUInteger held = host.inputs.length;
    if (held > 0 && buffer != NULL && held <= capacity) {
      memcpy(buffer, host.inputs.bytes, held);
      host.inputs.length = 0;
    }
    return (int64_t)held;
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
