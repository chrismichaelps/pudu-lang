#import "pudu_webview_macos.h"

/* Queued events past this many bytes are dropped until the program drains. */
#define PUDU_EVENT_LIMIT ((size_t)64 << 20)
/* The application-defined event subtype that only ends a pump's wait. */
#define PUDU_WAKE_SUBTYPE 0x5055

static pudu_buffer pudu_events;
static BOOL pudu_wake_posted;

NSString *pudu_field_string(pudu_field field) {
  return [[NSString alloc] initWithBytes:field.data length:field.length encoding:NSUTF8StringEncoding];
}

@implementation PuduWebContent
- (BOOL)isFlipped {
  return YES;
}
@end

@implementation PuduPendingRequest
@end

@implementation PuduWebWindow

- (BOOL)windowShouldClose:(NSWindow *)sender {
  (void)sender;
  [[PuduWebHost shared] event:@[ @"close-requested", @(self.identifier).stringValue ]];
  return NO;
}

- (void)windowDidResize:(NSNotification *)notification {
  (void)notification;
  NSSize size = self.window.contentView.bounds.size;
  [[PuduWebHost shared] event:@[
    @"resized", @(self.identifier).stringValue, @((long)size.width).stringValue,
    @((long)size.height).stringValue
  ]];
}

- (void)windowDidMove:(NSNotification *)notification {
  (void)notification;
  NSRect frame = self.window.frame;
  [[PuduWebHost shared] event:@[
    @"moved", @(self.identifier).stringValue, @((long)frame.origin.x).stringValue,
    @((long)frame.origin.y).stringValue
  ]];
}

- (void)windowDidBecomeKey:(NSNotification *)notification {
  (void)notification;
  [[PuduWebHost shared] event:@[ @"focused", @(self.identifier).stringValue, @"1" ]];
}

- (void)windowDidResignKey:(NSNotification *)notification {
  (void)notification;
  [[PuduWebHost shared] event:@[ @"focused", @(self.identifier).stringValue, @"0" ]];
}

@end

/* Quit asks every window to close rather than ending the process: the
   program decides, and closes what it owns in order. */
@interface PuduQuitTarget : NSObject
- (void)quit:(id)sender;
@end

@implementation PuduQuitTarget
- (void)quit:(id)sender {
  (void)sender;
  PuduWebHost *host = [PuduWebHost shared];
  for (NSNumber *identifier in host.windows) {
    [host event:@[ @"close-requested", identifier.stringValue ]];
  }
}
@end

static PuduQuitTarget *pudu_quit_target;

static NSMenuItem *pudu_menu_item(NSString *title, SEL action, NSString *key) {
  return [[NSMenuItem alloc] initWithTitle:title action:action keyEquivalent:key];
}

/* The application and Edit menus, whose standard actions are how editing
   shortcuts reach a focused WebView. */
static void pudu_install_menu(NSApplication *application) {
  if (application.mainMenu != nil) {
    return;
  }
  NSString *name = [[NSProcessInfo processInfo] processName];
  NSMenu *bar = [[NSMenu alloc] init];

  NSMenu *appMenu = [[NSMenu alloc] initWithTitle:name];
  pudu_quit_target = [[PuduQuitTarget alloc] init];
  NSMenuItem *quit = pudu_menu_item([@"Quit " stringByAppendingString:name], @selector(quit:), @"q");
  quit.target = pudu_quit_target;
  [appMenu addItem:pudu_menu_item(@"Hide", @selector(hide:), @"h")];
  [appMenu addItem:[NSMenuItem separatorItem]];
  [appMenu addItem:quit];
  NSMenuItem *appItem = [[NSMenuItem alloc] init];
  appItem.submenu = appMenu;
  [bar addItem:appItem];

  NSMenu *edit = [[NSMenu alloc] initWithTitle:@"Edit"];
  [edit addItem:pudu_menu_item(@"Undo", @selector(undo:), @"z")];
  NSMenuItem *redo = pudu_menu_item(@"Redo", @selector(redo:), @"z");
  redo.keyEquivalentModifierMask = NSEventModifierFlagCommand | NSEventModifierFlagShift;
  [edit addItem:redo];
  [edit addItem:[NSMenuItem separatorItem]];
  [edit addItem:pudu_menu_item(@"Cut", @selector(cut:), @"x")];
  [edit addItem:pudu_menu_item(@"Copy", @selector(copy:), @"c")];
  [edit addItem:pudu_menu_item(@"Paste", @selector(paste:), @"v")];
  [edit addItem:pudu_menu_item(@"Select All", @selector(selectAll:), @"a")];
  NSMenuItem *editItem = [[NSMenuItem alloc] init];
  editItem.submenu = edit;
  [bar addItem:editItem];

  application.mainMenu = bar;
}

@implementation PuduWebHost

+ (PuduWebHost *)shared {
  static PuduWebHost *host;
  if (host == nil) {
    host = [[PuduWebHost alloc] init];
    host.windows = [NSMutableDictionary dictionary];
    host.views = [NSMutableDictionary dictionary];
    host.pending = [NSMutableDictionary dictionary];
    host.nextRequest = 1;
    NSApplication *application = [NSApplication sharedApplication];
    [application setActivationPolicy:NSApplicationActivationPolicyRegular];
    pudu_install_menu(application);
    if (!application.isRunning) {
      [application finishLaunching];
    }
  }
  return host;
}

- (void)wake {
  if (pudu_wake_posted) {
    return;
  }
  pudu_wake_posted = YES;
  NSEvent *wake = [NSEvent otherEventWithType:NSEventTypeApplicationDefined
                                     location:NSZeroPoint
                                modifierFlags:0
                                    timestamp:0
                                 windowNumber:0
                                      context:nil
                                      subtype:PUDU_WAKE_SUBTYPE
                                        data1:0
                                        data2:0];
  [NSApp postEvent:wake atStart:NO];
}

- (void)eventData:(NSArray<NSData *> *)fields {
  if (pudu_events.length > PUDU_EVENT_LIMIT) {
    return;
  }
  size_t saved = pudu_events.length;
  for (NSData *field in fields) {
    if (pudu_buffer_field(&pudu_events, field.bytes, field.length) != 0) {
      pudu_events.length = saved;
      return;
    }
  }
  if (pudu_buffer_end(&pudu_events) != 0) {
    pudu_events.length = saved;
    return;
  }
  [self wake];
}

- (void)event:(NSArray<NSString *> *)fields {
  NSMutableArray<NSData *> *encoded = [NSMutableArray arrayWithCapacity:fields.count];
  for (NSString *field in fields) {
    [encoded addObject:[field dataUsingEncoding:NSUTF8StringEncoding] ?: [NSData data]];
  }
  [self eventData:encoded];
}

@end

static int32_t pudu_refuse(PuduWebHost *host, int32_t status, NSString *reason) {
  host.failure = reason;
  return status;
}

static int32_t pudu_window_open(PuduWebHost *host, int64_t identifier, pudu_field *fields, int count) {
  int64_t width = 0, height = 0, resizable = 0;
  if (count != 7 || pudu_field_int(fields[4], &width) != 0 ||
      pudu_field_int(fields[5], &height) != 0 || pudu_field_int(fields[6], &resizable) != 0 ||
      width <= 0 || height <= 0 || width > 100000 || height > 100000) {
    return pudu_refuse(host, PUDU_WEBVIEW_MALFORMED, @"window open needs a title, a positive size and a resizable flag");
  }
  if (host.windows[@(identifier)] != nil) {
    return pudu_refuse(host, PUDU_WEBVIEW_INVALID, @"window id is already open");
  }
  NSString *title = pudu_field_string(fields[3]);
  if (title == nil) {
    return pudu_refuse(host, PUDU_WEBVIEW_MALFORMED, @"window title is not UTF-8");
  }
  NSWindowStyleMask style = NSWindowStyleMaskTitled | NSWindowStyleMaskClosable |
      NSWindowStyleMaskMiniaturizable;
  if (resizable != 0) {
    style |= NSWindowStyleMaskResizable;
  }
  NSWindow *window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, width, height)
                                                 styleMask:style
                                                   backing:NSBackingStoreBuffered
                                                     defer:NO];
  if (window == nil) {
    return pudu_refuse(host, PUDU_WEBVIEW_PLATFORM, @"the window could not be created");
  }
  PuduWebWindow *owner = [[PuduWebWindow alloc] init];
  owner.identifier = identifier;
  owner.window = window;
  window.title = title;
  window.releasedWhenClosed = NO;
  window.delegate = owner;
  window.collectionBehavior = NSWindowCollectionBehaviorFullScreenPrimary;
  window.contentView = [[PuduWebContent alloc] initWithFrame:NSMakeRect(0, 0, width, height)];
  [window center];
  host.windows[@(identifier)] = owner;
  return PUDU_WEBVIEW_DONE;
}

static int32_t pudu_window_size(NSWindow *window, pudu_field *fields, int count, NSString *verb) {
  int64_t width = 0, height = 0;
  if (count != 5 || pudu_field_int(fields[3], &width) != 0 || pudu_field_int(fields[4], &height) != 0 ||
      width < 0 || height < 0) {
    return PUDU_WEBVIEW_MALFORMED;
  }
  NSSize size = NSMakeSize(width, height);
  if ([verb isEqualToString:@"size"]) {
    [window setContentSize:size];
  } else if ([verb isEqualToString:@"min-size"]) {
    window.contentMinSize = size;
  } else if ([verb isEqualToString:@"max-size"]) {
    window.contentMaxSize = NSMakeSize(width == 0 ? FLT_MAX : width, height == 0 ? FLT_MAX : height);
  } else {
    [window setFrameTopLeftPoint:NSMakePoint(width, NSMaxY(window.screen.frame) - height)];
  }
  return PUDU_WEBVIEW_DONE;
}

static int32_t pudu_window_command(PuduWebHost *host, pudu_field *fields, int count) {
  int64_t identifier = 0;
  if (count < 3 || pudu_field_int(fields[1], &identifier) != 0) {
    return pudu_refuse(host, PUDU_WEBVIEW_MALFORMED, @"window record needs an id and a verb");
  }
  NSString *verb = pudu_field_string(fields[2]) ?: @"";
  if ([verb isEqualToString:@"open"]) {
    return pudu_window_open(host, identifier, fields, count);
  }
  PuduWebWindow *owner = host.windows[@(identifier)];
  if (owner == nil) {
    return pudu_refuse(host, PUDU_WEBVIEW_UNKNOWN, [NSString stringWithFormat:@"window %lld is not open", identifier]);
  }
  NSWindow *window = owner.window;
  if ([verb isEqualToString:@"title"] && count == 4) {
    window.title = pudu_field_string(fields[3]) ?: window.title;
  } else if ([verb isEqualToString:@"size"] || [verb isEqualToString:@"min-size"] ||
             [verb isEqualToString:@"max-size"] || [verb isEqualToString:@"position"]) {
    if (pudu_window_size(window, fields, count, verb) != PUDU_WEBVIEW_DONE) {
      return pudu_refuse(host, PUDU_WEBVIEW_MALFORMED, [verb stringByAppendingString:@" needs two non-negative numbers"]);
    }
  } else if ([verb isEqualToString:@"center"]) {
    [window center];
  } else if ([verb isEqualToString:@"show"]) {
    [window makeKeyAndOrderFront:nil];
    [NSApp activateIgnoringOtherApps:YES];
  } else if ([verb isEqualToString:@"hide"]) {
    [window orderOut:nil];
  } else if ([verb isEqualToString:@"focus"]) {
    [window makeKeyAndOrderFront:nil];
  } else if ([verb isEqualToString:@"fullscreen"] && count == 4) {
    BOOL wanted = pudu_field_is(fields[3], "1");
    BOOL current = (window.styleMask & NSWindowStyleMaskFullScreen) != 0;
    if (wanted != current) {
      [window toggleFullScreen:nil];
    }
  } else if ([verb isEqualToString:@"close"]) {
    for (NSNumber *view in [host.views allKeys]) {
      if (host.views[view].windowIdentifier == identifier) {
        [host.views[view] detach];
        [host.views removeObjectForKey:view];
      }
    }
    window.delegate = nil;
    [window close];
    [host.windows removeObjectForKey:@(identifier)];
  } else {
    return pudu_refuse(host, PUDU_WEBVIEW_MALFORMED, [@"unknown window verb " stringByAppendingString:verb]);
  }
  return PUDU_WEBVIEW_DONE;
}

int32_t pudu_webview_send(const uint8_t *records, size_t length) {
  if (![NSThread isMainThread]) {
    return PUDU_WEBVIEW_NOT_MAIN;
  }
  if (records == NULL && length > 0) {
    return PUDU_WEBVIEW_INVALID;
  }
  @autoreleasepool {
    PuduWebHost *host = [PuduWebHost shared];
    host.failure = nil;
    size_t cursor = 0;
    pudu_field fields[PUDU_RECORD_FIELDS];
    for (;;) {
      int count = pudu_record_next(records, length, &cursor, fields, PUDU_RECORD_FIELDS);
      if (count == 0) {
        return PUDU_WEBVIEW_DONE;
      }
      if (count < 0) {
        return pudu_refuse(host, PUDU_WEBVIEW_MALFORMED, @"a command record is not framed");
      }
      int32_t status;
      @try {
        if (pudu_field_is(fields[0], "window")) {
          status = pudu_window_command(host, fields, count);
        } else if (pudu_field_is(fields[0], "view")) {
          status = pudu_webview_view_command(host, fields, count);
        } else if (pudu_field_is(fields[0], "app") || pudu_field_is(fields[0], "surface")) {
          status = pudu_webview_native_command(host, fields, count);
        } else {
          status = pudu_refuse(host, PUDU_WEBVIEW_MALFORMED, @"a record names neither a window nor a view");
        }
      } @catch (NSException *exception) {
        status = pudu_refuse(host, PUDU_WEBVIEW_PLATFORM, exception.reason ?: exception.name);
      }
      if (status != PUDU_WEBVIEW_DONE) {
        return status;
      }
    }
  }
}

int32_t pudu_webview_pump(int32_t milliseconds) {
  if (![NSThread isMainThread]) {
    return PUDU_WEBVIEW_NOT_MAIN;
  }
  if (milliseconds < 0) {
    return PUDU_WEBVIEW_INVALID;
  }
  @autoreleasepool {
    [PuduWebHost shared];
    NSDate *until = [NSDate dateWithTimeIntervalSinceNow:milliseconds / 1000.0];
    while (pudu_events.length == 0) {
      NSEvent *event = [NSApp nextEventMatchingMask:NSEventMaskAny
                                          untilDate:until
                                             inMode:NSDefaultRunLoopMode
                                            dequeue:YES];
      if (event == nil) {
        break;
      }
      if (event.type == NSEventTypeApplicationDefined && event.subtype == PUDU_WAKE_SUBTYPE) {
        pudu_wake_posted = NO;
        continue;
      }
      [NSApp sendEvent:event];
    }
    [NSApp updateWindows];
    return pudu_events.length > 0 ? PUDU_WEBVIEW_QUEUED : PUDU_WEBVIEW_DONE;
  }
}

int64_t pudu_webview_events(uint8_t *buffer, size_t capacity) {
  if (![NSThread isMainThread]) {
    return PUDU_WEBVIEW_NOT_MAIN;
  }
  return pudu_buffer_drain(&pudu_events, buffer, capacity);
}

int64_t pudu_webview_body(int64_t request, uint8_t *buffer, size_t capacity) {
  if (![NSThread isMainThread]) {
    return PUDU_WEBVIEW_NOT_MAIN;
  }
  PuduPendingRequest *pending = [PuduWebHost shared].pending[@(request)];
  if (pending == nil) {
    return PUDU_WEBVIEW_GONE;
  }
  NSData *body = pending.body ?: [NSData data];
  if (buffer != NULL && body.length <= capacity) {
    memcpy(buffer, body.bytes, body.length);
  }
  return (int64_t)body.length;
}

static NSDictionary<NSString *, NSString *> *pudu_header_fields(const uint8_t *head, size_t length) {
  NSMutableDictionary<NSString *, NSString *> *fields = [NSMutableDictionary dictionary];
  if (head == NULL || length == 0) {
    return fields;
  }
  NSString *text = [[NSString alloc] initWithBytes:head length:length encoding:NSUTF8StringEncoding];
  for (NSString *line in [text componentsSeparatedByString:@"\n"]) {
    NSRange colon = [line rangeOfString:@":"];
    if (colon.location == NSNotFound || colon.location == 0) {
      continue;
    }
    NSString *name = [line substringToIndex:colon.location];
    NSString *value = [[line substringFromIndex:colon.location + 1]
        stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    fields[name] = value;
  }
  return fields;
}

int32_t pudu_webview_respond(
    int64_t request,
    int32_t status,
    const uint8_t *head,
    size_t head_length,
    const uint8_t *body,
    size_t body_length) {
  if (![NSThread isMainThread]) {
    return PUDU_WEBVIEW_NOT_MAIN;
  }
  if (status < 100 || status > 599 || (body == NULL && body_length > 0)) {
    return PUDU_WEBVIEW_INVALID;
  }
  @autoreleasepool {
    PuduWebHost *host = [PuduWebHost shared];
    PuduPendingRequest *pending = host.pending[@(request)];
    [host.pending removeObjectForKey:@(request)];
    if (pending == nil || pending.stopped) {
      return PUDU_WEBVIEW_GONE;
    }
    @try {
      NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc]
           initWithURL:pending.task.request.URL
            statusCode:status
           HTTPVersion:@"HTTP/1.1"
          headerFields:pudu_header_fields(head, head_length)];
      [pending.task didReceiveResponse:response];
      if (body_length > 0) {
        [pending.task didReceiveData:[NSData dataWithBytes:body length:body_length]];
      }
      [pending.task didFinish];
      return PUDU_WEBVIEW_DONE;
    } @catch (NSException *exception) {
      host.failure = exception.reason;
      return PUDU_WEBVIEW_GONE;
    }
  }
}

int64_t pudu_webview_failure(uint8_t *buffer, size_t capacity) {
  if (![NSThread isMainThread]) {
    return PUDU_WEBVIEW_NOT_MAIN;
  }
  NSData *text = [[PuduWebHost shared].failure dataUsingEncoding:NSUTF8StringEncoding] ?: [NSData data];
  if (buffer != NULL && text.length <= capacity) {
    memcpy(buffer, text.bytes, text.length);
  }
  return (int64_t)text.length;
}
