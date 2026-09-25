#import "pudu_desktop.h"
#import "pudu_desktop_host.h"

/* Fields in one record: node parent role focused x y width height name. */
#define PUDU_ACCESS_FIELDS 9

/* The role string AppKit declares as NSAccessibilityHeadingRole from macOS 26;
   assistive clients understand it on every earlier release too. */
static NSString *const PuduHeadingRole = @"AXHeading";

/* An element that keeps its frame in top-left content pixels and answers
   screen coordinates through its view, so the frame follows the window. */
@interface PuduAccessElement : NSAccessibilityElement
@property(nonatomic, weak) NSView *view;
@property(nonatomic) NSRect contentFrame;
@end

@implementation PuduAccessElement

- (NSRect)accessibilityFrame {
  NSView *view = self.view;
  if (view == nil || view.window == nil) {
    return NSZeroRect;
  }
  NSRect local = self.contentFrame;
  if (!view.isFlipped) {
    local.origin.y = NSHeight(view.bounds) - NSMinY(local) - NSHeight(local);
  }
  return NSAccessibilityFrameInView(view, local);
}

@end

static NSDictionary<NSString *, NSAccessibilityRole> *pudu_access_roles(void) {
  static NSDictionary<NSString *, NSAccessibilityRole> *roles;
  static dispatch_once_t once;
  dispatch_once(&once, ^{
    roles = @{
      @"group": NSAccessibilityGroupRole,
      @"heading": PuduHeadingRole,
      @"label": NSAccessibilityStaticTextRole,
      @"image": NSAccessibilityImageRole,
      @"button": NSAccessibilityButtonRole,
      @"toggle": NSAccessibilityCheckBoxRole,
      @"field": NSAccessibilityTextFieldRole
    };
  });
  return roles;
}

/* A decimal of at most nine digits with an optional leading minus. */
static BOOL pudu_access_integer(NSString *text, long *value) {
  NSUInteger length = text.length;
  NSUInteger start = (length > 0 && [text characterAtIndex:0] == '-') ? 1 : 0;
  if (length == start || length - start > 9) {
    return NO;
  }
  long total = 0;
  for (NSUInteger at = start; at < length; at++) {
    unichar digit = [text characterAtIndex:at];
    if (digit < '0' || digit > '9') {
      return NO;
    }
    total = total * 10 + (digit - '0');
  }
  *value = start == 1 ? -total : total;
  return YES;
}

static NSString *pudu_access_spoken(NSString *name) {
  NSCharacterSet *breaks = [NSCharacterSet characterSetWithCharactersInString:@"\t\r\n"];
  return [[name componentsSeparatedByCharactersInSet:breaks] componentsJoinedByString:@" "];
}

int32_t pudu_desktop_accessibility(void *handle, const uint8_t *records, size_t length) {
  if (![NSThread isMainThread]) {
    return -2;
  }
  if (handle == NULL || (records == NULL && length > 0)) {
    return -1;
  }

  @autoreleasepool {
    @try {
      PuduWindowHost *host = (__bridge PuduWindowHost *)handle;
      PuduFrameView *view = host.frameView;
      NSString *text = length == 0 ? @"" : [[NSString alloc]
          initWithBytes:records
                 length:length
               encoding:NSUTF8StringEncoding];
      if (text == nil) {
        return -3;
      }

      /* Every record is read before anything is replaced. */
      NSMutableDictionary<NSNumber *, PuduAccessElement *> *built = [NSMutableDictionary dictionary];
      NSMutableDictionary<NSNumber *, NSMutableArray *> *children = [NSMutableDictionary dictionary];
      NSMutableArray *top = [NSMutableArray array];
      PuduAccessElement *focused = nil;
      for (NSString *line in [text componentsSeparatedByString:@"\n"]) {
        if (line.length == 0) {
          continue;
        }
        NSArray<NSString *> *fields = [line componentsSeparatedByString:@"\t"];
        long numbers[6];
        NSUInteger positions[6] = {0, 1, 4, 5, 6, 7};
        if (fields.count != PUDU_ACCESS_FIELDS) {
          return -3;
        }
        for (int at = 0; at < 6; at++) {
          if (!pudu_access_integer(fields[positions[at]], &numbers[at])) {
            return -3;
          }
        }
        NSAccessibilityRole role = pudu_access_roles()[fields[2]];
        NSString *flag = fields[3];
        NSNumber *node = @(numbers[0]);
        NSNumber *parent = @(numbers[1]);
        BOOL known = numbers[1] == -1 || built[parent] != nil;
        if (role == nil || !known || built[node] != nil || numbers[4] < 0 || numbers[5] < 0 ||
            !([flag isEqualToString:@"0"] || [flag isEqualToString:@"1"])) {
          return -3;
        }

        PuduAccessElement *element = [[PuduAccessElement alloc] init];
        element.view = view;
        element.contentFrame = NSMakeRect(numbers[2], numbers[3], numbers[4], numbers[5]);
        element.accessibilityRole = role;
        element.accessibilityLabel = pudu_access_spoken(fields[8]);
        if ([role isEqualToString:NSAccessibilityStaticTextRole] || [role isEqualToString:PuduHeadingRole]) {
          element.accessibilityValue = element.accessibilityLabel;
        }
        if ([flag isEqualToString:@"1"]) {
          element.accessibilityFocused = YES;
          focused = element;
        }
        built[node] = element;
        children[node] = [NSMutableArray array];
        if (numbers[1] == -1) {
          element.accessibilityParent = view;
          [top addObject:element];
        } else {
          element.accessibilityParent = built[parent];
          [children[parent] addObject:element];
        }
      }

      for (NSNumber *node in built) {
        built[node].accessibilityChildren = children[node];
      }
      view.accessibilityElement = YES;
      view.accessibilityRole = NSAccessibilityGroupRole;
      view.accessibilityLabel = host.window.title;
      view.accessibilityChildren = top;
      view.focusedElement = focused;
      NSAccessibilityPostNotification(view, NSAccessibilityLayoutChangedNotification);
      if (focused != nil) {
        NSAccessibilityPostNotification(focused, NSAccessibilityFocusedUIElementChangedNotification);
      }
      return 0;
    } @catch (NSException *exception) {
      (void)exception;
      return -4;
    }
  }
}

/* A screen frame as top-left pixels of the view's content. */
static NSRect pudu_access_content_frame(NSView *view, NSRect screen) {
  NSRect inWindow = [view.window convertRectFromScreen:screen];
  NSRect local = [view convertRect:inWindow fromView:nil];
  if (!view.isFlipped) {
    local.origin.y = NSHeight(view.bounds) - NSMinY(local) - NSHeight(local);
  }
  return local;
}

/* Appends each child and its descendants in preorder, numbered from counter. */
static void pudu_access_walk(NSArray *elements, long parent, long *counter, NSView *view, NSMutableString *out) {
  for (id<NSAccessibility> element in elements) {
    long node = (*counter)++;
    NSRect frame = pudu_access_content_frame(view, element.accessibilityFrame);
    NSString *role = element.accessibilityRole ?: @"";
    NSString *name = element.accessibilityLabel ?: @"";
    [out appendFormat:@"%ld\t%ld\t%@\t%d\t%ld\t%ld\t%ld\t%ld\t%@\n",
        node, parent, pudu_access_spoken(role), element.isAccessibilityFocused ? 1 : 0,
        lround(NSMinX(frame)), lround(NSMinY(frame)), lround(NSWidth(frame)), lround(NSHeight(frame)),
        pudu_access_spoken(name)];
    pudu_access_walk(element.accessibilityChildren, node, counter, view, out);
  }
}

int64_t pudu_desktop_accessibility_report(void *handle, uint8_t *buffer, size_t capacity) {
  if (![NSThread isMainThread]) {
    return -2;
  }
  if (handle == NULL) {
    return -1;
  }

  @autoreleasepool {
    @try {
      PuduWindowHost *host = (__bridge PuduWindowHost *)handle;
      NSMutableString *out = [NSMutableString string];
      long counter = 0;
      pudu_access_walk(host.frameView.accessibilityChildren, -1, &counter, host.frameView, out);
      NSData *bytes = [out dataUsingEncoding:NSUTF8StringEncoding];
      if (buffer != NULL && bytes.length <= capacity) {
        memcpy(buffer, bytes.bytes, bytes.length);
      }
      return (int64_t)bytes.length;
    } @catch (NSException *exception) {
      (void)exception;
      return -4;
    }
  }
}
