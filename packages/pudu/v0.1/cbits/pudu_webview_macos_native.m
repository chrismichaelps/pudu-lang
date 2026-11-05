#import "pudu_webview_macos.h"

/* A native pixel surface: flipped so rows run top to bottom like a Canvas frame. */
@interface PuduWebSurface : NSView
@property(nonatomic) int64_t surfaceId;
@property(nonatomic, strong) NSData *rgba;
@property(nonatomic) NSInteger pixelWidth;
@property(nonatomic) NSInteger pixelHeight;
@end

@implementation PuduWebSurface

- (BOOL)isFlipped {
  return YES;
}

- (void)drawRect:(NSRect)dirty {
  if (self.rgba == nil || self.pixelWidth <= 0 || self.pixelHeight <= 0) {
    [[NSColor clearColor] setFill];
    NSRectFill(dirty);
    return;
  }
  CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
  CGDataProviderRef provider = CGDataProviderCreateWithCFData((__bridge CFDataRef)self.rgba);
  CGImageRef image = CGImageCreate((size_t)self.pixelWidth, (size_t)self.pixelHeight, 8, 32, (size_t)self.pixelWidth * 4,
                                   space, kCGBitmapByteOrderDefault | kCGImageAlphaLast, provider, NULL, false,
                                   kCGRenderingIntentDefault);
  CGContextRef context = [[NSGraphicsContext currentContext] CGContext];
  CGContextSaveGState(context);
  /* The view is flipped, so the image is drawn upside down unless the context is flipped back. */
  CGContextTranslateCTM(context, 0, NSHeight(self.bounds));
  CGContextScaleCTM(context, 1, -1);
  CGContextSetInterpolationQuality(context, kCGInterpolationNone);
  CGContextDrawImage(context, NSMakeRect(0, 0, NSWidth(self.bounds), NSHeight(self.bounds)), image);
  CGContextRestoreGState(context);
  CGImageRelease(image);
  CGDataProviderRelease(provider);
  CGColorSpaceRelease(space);
}

- (void)mouseDown:(NSEvent *)event {
  NSPoint at = [self convertPoint:event.locationInWindow fromView:nil];
  double scaleX = NSWidth(self.bounds) > 0 ? self.pixelWidth / NSWidth(self.bounds) : 1;
  double scaleY = NSHeight(self.bounds) > 0 ? self.pixelHeight / NSHeight(self.bounds) : 1;
  [[PuduWebHost shared] event:@[
    @"surface-press", @(self.surfaceId).stringValue, @((long)(at.x * scaleX)).stringValue,
    @((long)(at.y * scaleY)).stringValue
  ]];
}

@end

/* What every program-defined menu item calls. */
@interface PuduWebMenuTarget : NSObject
- (void)choose:(NSMenuItem *)item;
@end

@implementation PuduWebMenuTarget
- (void)choose:(NSMenuItem *)item {
  [[PuduWebHost shared] event:@[ @"menu", item.representedObject ?: @"" ]];
}
@end

static NSMutableDictionary<NSNumber *, PuduWebSurface *> *pudu_surfaces;
static PuduWebMenuTarget *pudu_menu_target;

static int32_t pudu_native_refuse(PuduWebHost *host, int32_t status, NSString *reason) {
  host.failure = reason;
  return status;
}

static NSString *pudu_chord_key(NSString *chord, NSEventModifierFlags *flags) {
  *flags = 0;
  NSString *key = @"";
  for (NSString *part in [chord componentsSeparatedByString:@"+"]) {
    if ([part isEqualToString:@"cmd"]) {
      *flags |= NSEventModifierFlagCommand;
    } else if ([part isEqualToString:@"ctrl"]) {
      *flags |= NSEventModifierFlagControl;
    } else if ([part isEqualToString:@"alt"]) {
      *flags |= NSEventModifierFlagOption;
    } else if ([part isEqualToString:@"shift"]) {
      *flags |= NSEventModifierFlagShift;
    } else {
      key = part.lowercaseString;
    }
  }
  return key;
}

static int32_t pudu_install_menu_lines(PuduWebHost *host, NSString *text) {
  NSMenu *bar = [[NSMenu alloc] init];
  NSMenuItem *application = NSApp.mainMenu.itemArray.firstObject;
  if (application != nil) {
    [NSApp.mainMenu removeItem:application];
    [bar addItem:application];
  }
  if (pudu_menu_target == nil) {
    pudu_menu_target = [[PuduWebMenuTarget alloc] init];
  }
  NSMutableArray<NSMenu *> *open = [NSMutableArray arrayWithObject:bar];
  BOOL ownEdit = NO;
  for (NSString *line in [text componentsSeparatedByString:@"\n"]) {
    if (line.length == 0) {
      continue;
    }
    NSArray<NSString *> *parts = [line componentsSeparatedByString:@"\t"];
    NSInteger depth = parts.count > 1 ? parts[1].integerValue : -1;
    if (depth < 0 || depth >= (NSInteger)open.count) {
      return pudu_native_refuse(host, PUDU_WEBVIEW_MALFORMED, [@"a menu line is out of place: " stringByAppendingString:line]);
    }
    while ((NSInteger)open.count > depth + 1) {
      [open removeLastObject];
    }
    NSMenu *parent = open.lastObject;
    if ([parts[0] isEqualToString:@"menu"] && parts.count == 3) {
      NSMenu *menu = [[NSMenu alloc] initWithTitle:parts[2]];
      NSMenuItem *holder = [[NSMenuItem alloc] initWithTitle:parts[2] action:nil keyEquivalent:@""];
      holder.submenu = menu;
      [parent addItem:holder];
      [open addObject:menu];
      ownEdit = ownEdit || (depth == 0 && [parts[2] isEqualToString:@"Edit"]);
    } else if ([parts[0] isEqualToString:@"item"] && parts.count == 5) {
      NSEventModifierFlags flags = 0;
      NSString *key = pudu_chord_key(parts[3], &flags);
      NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:parts[4] action:@selector(choose:) keyEquivalent:key];
      item.keyEquivalentModifierMask = key.length > 0 ? flags : 0;
      item.target = pudu_menu_target;
      item.representedObject = parts[2];
      [parent addItem:item];
    } else if ([parts[0] isEqualToString:@"separator"] && parts.count == 2) {
      [parent addItem:[NSMenuItem separatorItem]];
    } else {
      return pudu_native_refuse(host, PUDU_WEBVIEW_MALFORMED, [@"a menu line is malformed: " stringByAppendingString:line]);
    }
  }
  if (!ownEdit) {
    for (NSMenuItem *item in NSApp.mainMenu.itemArray) {
      if ([item.title isEqualToString:@"Edit"]) {
        [NSApp.mainMenu removeItem:item];
        [bar insertItem:item atIndex:MIN((NSInteger)1, (NSInteger)bar.numberOfItems)];
        break;
      }
    }
  }
  NSApp.mainMenu = bar;
  return PUDU_WEBVIEW_DONE;
}

static void pudu_answer_panel(NSString *ticket, NSModalResponse response, NSArray<NSURL *> *urls) {
  if (response != NSModalResponseOK) {
    [[PuduWebHost shared] event:@[ @"dialog-cancel", ticket ]];
    return;
  }
  NSMutableArray<NSString *> *paths = [NSMutableArray array];
  for (NSURL *url in urls) {
    [paths addObject:url.path ?: @""];
  }
  [[PuduWebHost shared] event:@[ @"dialog-ok", ticket, [paths componentsJoinedByString:@"\n"] ]];
}

static int32_t pudu_dialog(PuduWebHost *host, NSArray<NSString *> *fields) {
  if (fields.count < 5) {
    return pudu_native_refuse(host, PUDU_WEBVIEW_MALFORMED, @"a dialog needs a ticket, a kind and a title");
  }
  NSString *ticket = fields[2];
  NSString *kind = fields[3];
  if ([kind isEqualToString:@"open"] && fields.count == 7) {
    NSOpenPanel *panel = [NSOpenPanel openPanel];
    panel.message = fields[4];
    panel.allowsMultipleSelection = [fields[5] isEqualToString:@"1"];
    panel.canChooseDirectories = [fields[6] isEqualToString:@"1"];
    panel.canChooseFiles = !panel.canChooseDirectories;
    [panel beginWithCompletionHandler:^(NSModalResponse response) {
      pudu_answer_panel(ticket, response, panel.URLs);
    }];
  } else if ([kind isEqualToString:@"save"] && fields.count == 6) {
    NSSavePanel *panel = [NSSavePanel savePanel];
    panel.message = fields[4];
    panel.nameFieldStringValue = fields[5];
    [panel beginWithCompletionHandler:^(NSModalResponse response) {
      pudu_answer_panel(ticket, response, panel.URL == nil ? @[] : @[ panel.URL ]);
    }];
  } else if ([kind isEqualToString:@"message"] && fields.count == 8) {
    NSAlert *alert = [[NSAlert alloc] init];
    alert.alertStyle = [fields[4] isEqualToString:@"critical"] ? NSAlertStyleCritical
                       : [fields[4] isEqualToString:@"warning"] ? NSAlertStyleWarning
                                                                 : NSAlertStyleInformational;
    alert.messageText = fields[5];
    alert.informativeText = fields[6];
    for (NSString *button in [fields[7] componentsSeparatedByString:@","]) {
      [alert addButtonWithTitle:button];
    }
    NSWindow *parent = host.windows.allValues.firstObject.window;
    void (^answer)(NSModalResponse) = ^(NSModalResponse response) {
      [[PuduWebHost shared] event:@[ @"dialog-ok", ticket, @((long)(response - NSAlertFirstButtonReturn)).stringValue ]];
    };
    if (parent != nil) {
      [alert beginSheetModalForWindow:parent completionHandler:answer];
    } else {
      answer([alert runModal]);
    }
  } else {
    return pudu_native_refuse(host, PUDU_WEBVIEW_MALFORMED, [@"unknown dialog " stringByAppendingString:kind]);
  }
  return PUDU_WEBVIEW_DONE;
}

static int32_t pudu_surface(PuduWebHost *host, NSArray<NSString *> *fields) {
  if (pudu_surfaces == nil) {
    pudu_surfaces = [NSMutableDictionary dictionary];
  }
  if (fields.count < 3) {
    return pudu_native_refuse(host, PUDU_WEBVIEW_MALFORMED, @"a surface record needs an id and a verb");
  }
  NSNumber *identifier = @(fields[1].longLongValue);
  NSString *verb = fields[2];
  if ([verb isEqualToString:@"create"] && fields.count == 8) {
    PuduWebWindow *owner = host.windows[@(fields[3].longLongValue)];
    if (owner == nil) {
      return pudu_native_refuse(host, PUDU_WEBVIEW_UNKNOWN, @"the surface's window is not open");
    }
    if (pudu_surfaces[identifier] != nil) {
      return pudu_native_refuse(host, PUDU_WEBVIEW_INVALID, @"surface id is already in use");
    }
    PuduWebSurface *surface = [[PuduWebSurface alloc] initWithFrame:NSMakeRect(fields[4].doubleValue, fields[5].doubleValue,
                                                                         fields[6].doubleValue, fields[7].doubleValue)];
    surface.surfaceId = identifier.longLongValue;
    [owner.window.contentView addSubview:surface positioned:NSWindowAbove relativeTo:nil];
    pudu_surfaces[identifier] = surface;
    return PUDU_WEBVIEW_DONE;
  }
  PuduWebSurface *surface = pudu_surfaces[identifier];
  if (surface == nil) {
    return pudu_native_refuse(host, PUDU_WEBVIEW_UNKNOWN, @"surface does not exist");
  }
  if ([verb isEqualToString:@"present"] && fields.count == 6) {
    NSInteger width = fields[3].integerValue;
    NSInteger height = fields[4].integerValue;
    NSData *rgba = [[NSData alloc] initWithBase64EncodedString:fields[5] options:0];
    if (width <= 0 || height <= 0 || rgba == nil || rgba.length != (NSUInteger)(width * height * 4)) {
      return pudu_native_refuse(host, PUDU_WEBVIEW_MALFORMED, @"a surface frame does not match its size");
    }
    surface.rgba = rgba;
    surface.pixelWidth = width;
    surface.pixelHeight = height;
    surface.needsDisplay = YES;
  } else if ([verb isEqualToString:@"close"]) {
    [surface removeFromSuperview];
    [pudu_surfaces removeObjectForKey:identifier];
  } else {
    return pudu_native_refuse(host, PUDU_WEBVIEW_MALFORMED, [@"unknown surface command " stringByAppendingString:verb]);
  }
  return PUDU_WEBVIEW_DONE;
}

int32_t pudu_webview_native_command(PuduWebHost *host, pudu_field *fields, int count) {
  NSMutableArray<NSString *> *texts = [NSMutableArray arrayWithCapacity:(NSUInteger)count];
  for (int i = 0; i < count; i++) {
    NSString *text = pudu_field_string(fields[i]);
    if (text == nil) {
      return pudu_native_refuse(host, PUDU_WEBVIEW_MALFORMED, @"a native record is not UTF-8");
    }
    [texts addObject:text];
  }
  if ([texts[0] isEqualToString:@"surface"]) {
    return pudu_surface(host, texts);
  }
  if (count == 3 && [texts[1] isEqualToString:@"menu"]) {
    return pudu_install_menu_lines(host, texts[2]);
  }
  if (count > 1 && [texts[1] isEqualToString:@"dialog"]) {
    return pudu_dialog(host, texts);
  }
  return pudu_native_refuse(host, PUDU_WEBVIEW_MALFORMED, @"unknown application record");
}
