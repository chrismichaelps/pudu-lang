#import "pudu_webview_macos.h"

static NSString *pudu_flag(BOOL value) { return value ? @"1" : @"0"; }

void pudu_report_window_state(PuduWebWindow *owner) {
  NSWindow *window = owner.window;
  [[PuduWebHost shared] event:@[
    @"window-state", @(owner.identifier).stringValue, pudu_flag(window.miniaturized), pudu_flag(window.zoomed),
    pudu_flag((window.styleMask & NSWindowStyleMaskFullScreen) != 0), pudu_flag(window.visible), pudu_flag(window.keyWindow)
  ]];
}

void pudu_report_window_scale(PuduWebWindow *owner) {
  [[PuduWebHost shared] event:@[
    @"scale", @(owner.identifier).stringValue, @((long)lround(owner.window.backingScaleFactor * 1000)).stringValue
  ]];
}

NSString *pudu_theme_name(NSAppearance *appearance) {
  NSAppearanceName match = [appearance bestMatchFromAppearancesWithNames:@[ NSAppearanceNameAqua, NSAppearanceNameDarkAqua ]];
  return [match isEqualToString:NSAppearanceNameDarkAqua] ? @"dark" : @"light";
}

@implementation PuduWebKitView

- (NSDragOperation)draggingEntered:(id<NSDraggingInfo>)sender {
  if (!self.dropEnabled) {
    return [super draggingEntered:sender];
  }
  [self reportDrop:@"drop-enter" info:sender withPaths:YES];
  return NSDragOperationCopy;
}

- (NSDragOperation)draggingUpdated:(id<NSDraggingInfo>)sender {
  if (!self.dropEnabled) {
    return [super draggingUpdated:sender];
  }
  [self reportDrop:@"drop-over" info:sender withPaths:NO];
  return NSDragOperationCopy;
}

- (void)draggingExited:(id<NSDraggingInfo>)sender {
  if (!self.dropEnabled) {
    [super draggingExited:sender];
    return;
  }
  [[PuduWebHost shared] event:@[ @"drop-leave", @(self.viewIdentifier).stringValue ]];
}

- (BOOL)performDragOperation:(id<NSDraggingInfo>)sender {
  if (!self.dropEnabled) {
    return [super performDragOperation:sender];
  }
  [self reportDrop:@"drop" info:sender withPaths:YES];
  return YES;
}

- (void)reportDrop:(NSString *)verb info:(id<NSDraggingInfo>)info withPaths:(BOOL)paths {
  NSPoint at = [self convertPoint:info.draggingLocation fromView:nil];
  long y = (long)(self.isFlipped ? at.y : NSHeight(self.bounds) - at.y);
  NSMutableArray<NSString *> *fields = [NSMutableArray arrayWithArray:@[
    verb, @(self.viewIdentifier).stringValue, @((long)at.x).stringValue, @(y).stringValue
  ]];
  if (paths) {
    NSArray<NSURL *> *urls = [info.draggingPasteboard readObjectsForClasses:@[ [NSURL class] ]
                                                                    options:@{NSPasteboardURLReadingFileURLsOnlyKey : @YES}];
    NSMutableArray<NSString *> *names = [NSMutableArray array];
    for (NSURL *url in urls) {
      [names addObject:url.path ?: @""];
    }
    NSData *encoded = [NSJSONSerialization dataWithJSONObject:names options:0 error:nil];
    [fields addObject:[[NSString alloc] initWithData:encoded encoding:NSUTF8StringEncoding]];
  }
  [[PuduWebHost shared] event:fields];
}

@end

@implementation PuduWindowMessages

- (void)userContentController:(WKUserContentController *)controller didReceiveScriptMessage:(WKScriptMessage *)message {
  (void)controller;
  NSWindow *window = message.webView.window;
  if (window == nil || !message.frameInfo.mainFrame || ![message.body isKindOfClass:[NSString class]]) {
    return;
  }
  NSString *allowed = self.view.windowActions[message.body];
  NSURL *url = message.frameInfo.request.URL;
  NSString *origin = [NSString stringWithFormat:@"%@://%@%@", url.scheme.lowercaseString, url.host.lowercaseString,
                      url.port == nil ? @"" : [@":" stringByAppendingString:url.port.stringValue]];
  if (allowed == nil || ![allowed isEqualToString:origin]) {
    return;
  }
  if ([message.body isEqualToString:@"drag"]) {
    NSEvent *event = NSApp.currentEvent;
    if (event.type == NSEventTypeLeftMouseDown && event.window == window && (NSEvent.pressedMouseButtons & 1) != 0) {
      [window performWindowDragWithEvent:event];
    }
  } else if ([message.body isEqualToString:@"toggle-maximize"]) {
    [window zoom:nil];
  }
}

@end

PuduWebKitView *pudu_webview_interactive_view(PuduWebView *view, WKWebViewConfiguration *configuration) {
  PuduWindowMessages *messages = [[PuduWindowMessages alloc] init];
  messages.view = view;
  [configuration.userContentController addScriptMessageHandler:messages name:@"puduWindow"];
  PuduWebKitView *webView = [[PuduWebKitView alloc] initWithFrame:view.frame configuration:configuration];
  webView.viewIdentifier = view.identifier;
  webView.dropEnabled = view.fileDrop;
  return webView;
}

int32_t pudu_webview_window_permission(PuduWebHost *host, PuduWebView *view, pudu_field *fields, int count) {
  if (count != 5 || !(pudu_field_is(fields[3], "drag") || pudu_field_is(fields[3], "toggle-maximize"))) {
    host.failure = @"window-action needs an action and an origin";
    return PUDU_WEBVIEW_MALFORMED;
  }
  NSString *origin = pudu_field_string(fields[4]);
  if (origin.length == 0) {
    host.failure = @"window-action needs an origin";
    return PUDU_WEBVIEW_MALFORMED;
  }
  view.windowActions[pudu_field_string(fields[3])] = origin;
  return PUDU_WEBVIEW_DONE;
}

static BOOL pudu_flag_field(pudu_field field) { return pudu_field_is(field, "1"); }

static void pudu_set_style(NSWindow *window, NSWindowStyleMask mask, BOOL on) {
  window.styleMask = on ? (window.styleMask | mask) : (window.styleMask & ~mask);
}

int32_t pudu_webview_window_extra(PuduWebHost *host, PuduWebWindow *owner, NSString *verb, pudu_field *fields, int count) {
  NSWindow *window = owner.window;
  NSSet *bare = [NSSet setWithArray:@[@"minimize", @"unminimize", @"maximize", @"unmaximize", @"toggle-maximize", @"state"]];
  NSSet *flags = [NSSet setWithArray:@[@"always-on-top", @"decorations", @"closable", @"minimizable", @"maximizable", @"resizable", @"content-protected"]];
  if (([bare containsObject:verb] && count != 3) ||
      ([flags containsObject:verb] && (count != 4 || !(pudu_field_is(fields[3], "0") || pudu_field_is(fields[3], "1"))))) {
    return PUDU_WEBVIEW_MALFORMED;
  }
  BOOL value = count == 4 && pudu_flag_field(fields[3]);
  if ([verb isEqualToString:@"minimize"]) {
    [window miniaturize:nil];
  } else if ([verb isEqualToString:@"unminimize"]) {
    [window deminiaturize:nil];
  } else if ([verb isEqualToString:@"maximize"]) {
    if (!window.zoomed) {
      [window zoom:nil];
    }
  } else if ([verb isEqualToString:@"unmaximize"]) {
    if (window.zoomed) {
      [window zoom:nil];
    }
  } else if ([verb isEqualToString:@"toggle-maximize"]) {
    [window zoom:nil];
  } else if ([verb isEqualToString:@"always-on-top"] && count == 4) {
    window.level = value ? NSFloatingWindowLevel : NSNormalWindowLevel;
  } else if ([verb isEqualToString:@"decorations"] && count == 4) {
    pudu_set_style(window, NSWindowStyleMaskTitled, value);
  } else if ([verb isEqualToString:@"closable"] && count == 4) {
    pudu_set_style(window, NSWindowStyleMaskClosable, value);
  } else if ([verb isEqualToString:@"minimizable"] && count == 4) {
    pudu_set_style(window, NSWindowStyleMaskMiniaturizable, value);
  } else if ([verb isEqualToString:@"maximizable"] && count == 4) {
    [window standardWindowButton:NSWindowZoomButton].enabled = value;
  } else if ([verb isEqualToString:@"resizable"] && count == 4) {
    pudu_set_style(window, NSWindowStyleMaskResizable, value);
  } else if ([verb isEqualToString:@"background"] && count == 7) {
    int64_t channel[4] = {0, 0, 0, 255};
    for (int i = 0; i < 4; i++) {
      if (pudu_field_int(fields[3 + i], &channel[i]) != 0 || channel[i] < 0 || channel[i] > 255) {
        return PUDU_WEBVIEW_MALFORMED;
      }
    }
    window.backgroundColor = [NSColor colorWithSRGBRed:channel[0] / 255.0 green:channel[1] / 255.0 blue:channel[2] / 255.0 alpha:channel[3] / 255.0];
    window.opaque = channel[3] == 255;
  } else if ([verb isEqualToString:@"titlebar"] && count == 4) {
    if (!(pudu_field_is(fields[3], "visible") || pudu_field_is(fields[3], "transparent") || pudu_field_is(fields[3], "overlay"))) {
      return PUDU_WEBVIEW_MALFORMED;
    }
    BOOL overlay = pudu_field_is(fields[3], "overlay");
    window.titlebarAppearsTransparent = overlay || pudu_field_is(fields[3], "transparent");
    window.titleVisibility = overlay ? NSWindowTitleHidden : NSWindowTitleVisible;
    pudu_set_style(window, NSWindowStyleMaskFullSizeContentView, overlay);
  } else if ([verb isEqualToString:@"attention"] && count == 4) {
    if (!(pudu_field_is(fields[3], "critical") || pudu_field_is(fields[3], "informational"))) {
      return PUDU_WEBVIEW_MALFORMED;
    }
    [NSApp requestUserAttention:pudu_field_is(fields[3], "critical") ? NSCriticalRequest : NSInformationalRequest];
  } else if ([verb isEqualToString:@"badge"] && count == 4) {
    NSString *label = pudu_field_string(fields[3]);
    NSApp.dockTile.badgeLabel = label.length == 0 ? nil : label;
  } else if ([verb isEqualToString:@"content-protected"] && count == 4) {
    window.sharingType = value ? NSWindowSharingNone : NSWindowSharingReadOnly;
  } else if ([verb isEqualToString:@"state"]) {
    NSRect frame = window.frame;
    NSSize size = window.contentView.bounds.size;
    [host event:@[@"moved", @(owner.identifier).stringValue, @((long)frame.origin.x).stringValue,
                  @((long)(NSMaxY(window.screen.frame) - NSMaxY(frame))).stringValue]];
    [host event:@[@"resized", @(owner.identifier).stringValue, @((long)size.width).stringValue, @((long)size.height).stringValue]];
    pudu_report_window_scale(owner);
    [host event:@[ @"theme", pudu_theme_name(NSApp.effectiveAppearance) ]];
  } else {
    host.failure = [@"unknown window verb " stringByAppendingString:verb];
    return PUDU_WEBVIEW_MALFORMED;
  }
  pudu_report_window_state(owner);
  return PUDU_WEBVIEW_DONE;
}

static BOOL pudu_inspector_visible(WKWebView *webView) {
  id inspector = [webView valueForKey:@"_inspector"];
  SEL visible = NSSelectorFromString(@"isVisible");
  if (inspector == nil || ![inspector respondsToSelector:visible]) {
    return NO;
  }
  return ((BOOL(*)(id, SEL))objc_msgSend)(inspector, visible);
}

int32_t pudu_webview_view_extra(PuduWebHost *host, PuduWebView *view, NSString *verb, pudu_field *fields, int count) {
  (void)fields;
  (void)count;
  WKWebView *webView = view.webView;
  if (count != 3) { return PUDU_WEBVIEW_MALFORMED; }
  if ([verb isEqualToString:@"devtools-toggle"] || [verb isEqualToString:@"devtools-state"] ||
      [verb isEqualToString:@"devtools-open"] || [verb isEqualToString:@"devtools-close"]) {
    if (!view.devtools) {
      host.failure = @"developer tools are disabled for this view";
      return PUDU_WEBVIEW_UNSUPPORTED;
    }
    BOOL open = pudu_inspector_visible(webView);
    if (![verb isEqualToString:@"devtools-state"]) {
      BOOL wanted = [verb isEqualToString:@"devtools-open"] || ([verb isEqualToString:@"devtools-toggle"] && !open);
      id inspector = [webView valueForKey:@"_inspector"];
      SEL action = NSSelectorFromString(wanted ? @"show" : @"close");
      if (inspector == nil || ![inspector respondsToSelector:action]) {
        host.failure = @"the inspector cannot be opened programmatically";
        return PUDU_WEBVIEW_UNSUPPORTED;
      }
      ((void (*)(id, SEL))objc_msgSend)(inspector, action);
      open = wanted;
    }
    [host event:@[ @"devtools", @(view.identifier).stringValue, open ? @"open" : @"closed" ]];
  } else if ([verb isEqualToString:@"print"]) {
    NSPrintOperation *operation = [webView printOperationWithPrintInfo:[NSPrintInfo sharedPrintInfo]];
    operation.showsPrintPanel = YES;
    [operation runOperationModalForWindow:webView.window delegate:nil didRunSelector:nil contextInfo:NULL];
  } else if ([verb isEqualToString:@"clear-data"]) {
    WKWebsiteDataStore *store = webView.configuration.websiteDataStore;
    NSString *label = @(view.identifier).stringValue;
    [store removeDataOfTypes:[WKWebsiteDataStore allWebsiteDataTypes]
               modifiedSince:[NSDate distantPast]
           completionHandler:^{
             [[PuduWebHost shared] event:@[ @"data-cleared", label ]];
           }];
  } else {
    host.failure = [@"unknown view command " stringByAppendingString:verb];
    return PUDU_WEBVIEW_MALFORMED;
  }
  return PUDU_WEBVIEW_DONE;
}
