#import "pudu_webview_macos.h"

#import <CommonCrypto/CommonDigest.h>
#import <objc/message.h>

static int32_t pudu_view_refuse(PuduWebHost *host, int32_t status, NSString *reason) {
  host.failure = reason;
  return status;
}

static NSString *pudu_text(id value) {
  if (value == nil || value == [NSNull null]) {
    return @"null";
  }
  if ([value isKindOfClass:[NSString class]]) {
    return value;
  }
  NSData *json = [NSJSONSerialization dataWithJSONObject:value
                                                 options:NSJSONWritingFragmentsAllowed
                                                   error:nil];
  return json == nil ? [value description] : [[NSString alloc] initWithData:json encoding:NSUTF8StringEncoding];
}

/* A JavaScript string literal holding text. */
static NSString *pudu_literal(NSString *text) {
  NSData *json = [NSJSONSerialization dataWithJSONObject:text
                                                 options:NSJSONWritingFragmentsAllowed
                                                   error:nil];
  return json == nil ? @"\"\"" : [[NSString alloc] initWithData:json encoding:NSUTF8StringEncoding];
}

/* A stable identifier for a named data store: the first sixteen bytes of
   the name's SHA-256, marked as a name-based identifier. */
static NSUUID *pudu_store_identifier(NSString *name) {
  NSData *bytes = [name dataUsingEncoding:NSUTF8StringEncoding];
  unsigned char digest[CC_SHA256_DIGEST_LENGTH];
  CC_SHA256(bytes.bytes, (CC_LONG)bytes.length, digest);
  digest[6] = (unsigned char)((digest[6] & 0x0F) | 0x50);
  digest[8] = (unsigned char)((digest[8] & 0x3F) | 0x80);
  return [[NSUUID alloc] initWithUUIDBytes:digest];
}

@implementation PuduWebView

- (void)report:(NSArray<NSString *> *)fields {
  [[PuduWebHost shared] event:fields];
}

- (NSString *)label {
  return @(self.identifier).stringValue;
}

- (void)webView:(WKWebView *)webView startURLSchemeTask:(id<WKURLSchemeTask>)task {
  PuduWebHost *host = [PuduWebHost shared];
  int64_t identifier = host.nextRequest++;
  PuduPendingRequest *pending = [[PuduPendingRequest alloc] init];
  pending.task = task;
  NSURLRequest *request = task.request;
  NSData *body = request.HTTPBody;
  if (body == nil && request.HTTPBodyStream != nil) {
    NSMutableData *drained = [NSMutableData data];
    NSInputStream *stream = request.HTTPBodyStream;
    uint8_t chunk[65536];
    [stream open];
    for (;;) {
      NSInteger read = [stream read:chunk maxLength:sizeof chunk];
      if (read <= 0) {
        break;
      }
      [drained appendBytes:chunk length:(NSUInteger)read];
    }
    [stream close];
    body = drained;
  }
  pending.body = body ?: [NSData data];
  host.pending[@(identifier)] = pending;

  NSMutableString *headers = [NSMutableString string];
  [request.allHTTPHeaderFields enumerateKeysAndObjectsUsingBlock:^(NSString *name, NSString *value, BOOL *stop) {
    (void)stop;
    [headers appendFormat:@"%@: %@\n", name, value];
  }];
  [self report:@[
    @"request", self.label, @(identifier).stringValue, request.HTTPMethod ?: @"GET",
    request.URL.absoluteString ?: @"", headers, @(pending.body.length).stringValue,
    webView.URL.absoluteString ?: @""
  ]];
}

- (void)webView:(WKWebView *)webView stopURLSchemeTask:(id<WKURLSchemeTask>)task {
  (void)webView;
  PuduWebHost *host = [PuduWebHost shared];
  for (NSNumber *identifier in [host.pending allKeys]) {
    if (host.pending[identifier].task == task) {
      host.pending[identifier].stopped = YES;
      [host.pending removeObjectForKey:identifier];
    }
  }
}

- (BOOL)allows:(NSURL *)url {
  NSString *scheme = url.scheme.lowercaseString;
  if ([scheme isEqualToString:@"pudu"] || [scheme isEqualToString:@"about"] ||
      [scheme isEqualToString:@"data"] || [scheme isEqualToString:@"blob"]) {
    return YES;
  }
  const char *text = url.absoluteString.UTF8String;
  for (NSString *pattern in self.allowed) {
    if (text != NULL && pudu_pattern_match(pattern.UTF8String, text)) {
      return YES;
    }
  }
  return NO;
}

- (void)webView:(WKWebView *)webView
    decidePolicyForNavigationAction:(WKNavigationAction *)action
                    decisionHandler:(void (^)(WKNavigationActionPolicy))decision {
  (void)webView;
  NSURL *url = action.request.URL;
  if (action.targetFrame == nil) {
    [self report:@[ @"new-window-blocked", self.label, url.absoluteString ?: @"" ]];
    decision(WKNavigationActionPolicyCancel);
    return;
  }
  if ([self allows:url]) {
    decision(WKNavigationActionPolicyAllow);
    return;
  }
  [self report:@[ @"navigation-blocked", self.label, url.absoluteString ?: @"" ]];
  decision(WKNavigationActionPolicyCancel);
}

- (void)webView:(WKWebView *)webView didCommitNavigation:(WKNavigation *)navigation {
  (void)navigation;
  [self report:@[ @"navigated", self.label, webView.URL.absoluteString ?: @"" ]];
}

- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation {
  (void)navigation;
  [self report:@[ @"loaded", self.label, webView.URL.absoluteString ?: @"" ]];
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary<NSKeyValueChangeKey, id> *)change
                       context:(void *)context {
  (void)keyPath;
  (void)change;
  (void)context;
  [self report:@[ @"title", self.label, ((WKWebView *)object).title ?: @"" ]];
}

- (void)detach {
  if (self.webView != nil) {
    [self.webView removeObserver:self forKeyPath:@"title"];
    [self.webView stopLoading];
    [self.webView removeFromSuperview];
    self.webView = nil;
  }
}

- (void)webViewWebContentProcessDidTerminate:(WKWebView *)webView {
  (void)webView;
  [self report:@[ @"crashed", self.label ]];
}

- (WKWebView *)webView:(WKWebView *)webView
    createWebViewWithConfiguration:(WKWebViewConfiguration *)configuration
               forNavigationAction:(WKNavigationAction *)action
                    windowFeatures:(WKWindowFeatures *)features {
  (void)webView;
  (void)configuration;
  (void)features;
  [self report:@[ @"new-window-blocked", self.label, action.request.URL.absoluteString ?: @"" ]];
  return nil;
}

- (void)webView:(WKWebView *)webView
    runJavaScriptAlertPanelWithMessage:(NSString *)message
                      initiatedByFrame:(WKFrameInfo *)frame
                     completionHandler:(void (^)(void))done {
  (void)webView;
  (void)frame;
  NSAlert *alert = [[NSAlert alloc] init];
  alert.messageText = message;
  [alert runModal];
  done();
}

- (void)webView:(WKWebView *)webView
    runJavaScriptConfirmPanelWithMessage:(NSString *)message
                        initiatedByFrame:(WKFrameInfo *)frame
                       completionHandler:(void (^)(BOOL))done {
  (void)webView;
  (void)frame;
  NSAlert *alert = [[NSAlert alloc] init];
  alert.messageText = message;
  [alert addButtonWithTitle:@"OK"];
  [alert addButtonWithTitle:@"Cancel"];
  done([alert runModal] == NSAlertFirstButtonReturn);
}

@end

static WKUserScript *pudu_style_script(NSString *css) {
  NSString *source = [NSString stringWithFormat:
      @"(function(){var s=document.createElement('style');s.textContent=%@;"
       "var put=function(){(document.head||document.documentElement).appendChild(s)};"
       "if(document.documentElement){put()}else{document.addEventListener('DOMContentLoaded',put)}})();",
      pudu_literal(css)];
  return [[WKUserScript alloc] initWithSource:source
                                injectionTime:WKUserScriptInjectionTimeAtDocumentStart
                             forMainFrameOnly:YES];
}

static WKWebsiteDataStore *pudu_store(PuduWebView *view) {
  if (view.ephemeral) {
    return [WKWebsiteDataStore nonPersistentDataStore];
  }
  if (view.dataStore.length > 0) {
    if (@available(macOS 14.0, *)) {
      return [WKWebsiteDataStore dataStoreForIdentifier:pudu_store_identifier(view.dataStore)];
    }
    [view report:@[ @"data-store", view.label, @"shared" ]];
  }
  return [WKWebsiteDataStore defaultDataStore];
}

/* The page a view was configured with, loaded only once every rule list is
   in place, so no request escapes rules that were still compiling. */
static void pudu_load_initial(PuduWebView *view) {
  if (view.initialHTML != nil) {
    [view.webView loadHTMLString:view.initialHTML baseURL:[NSURL URLWithString:@"pudu://app/"]];
  } else if (view.initialURL != nil) {
    NSURL *url = [NSURL URLWithString:view.initialURL];
    if (url != nil) {
      [view.webView loadRequest:[NSURLRequest requestWithURL:url]];
    }
  }
}

/* Compiles every rule list, then loads the initial page; a list that fails
   to compile leaves the view empty rather than unprotected. */
static void pudu_compile_rules(PuduWebView *view, WKUserContentController *content) {
  __block NSUInteger outstanding = view.ruleSources.count;
  __block BOOL failed = NO;
  if (outstanding == 0) {
    pudu_load_initial(view);
    return;
  }
  NSUInteger index = 0;
  for (NSString *source in view.ruleSources) {
    NSString *name = [NSString stringWithFormat:@"pudu-%lld-%lu", view.identifier, (unsigned long)index++];
    [[WKContentRuleListStore defaultStore]
        compileContentRuleListForIdentifier:name
                     encodedContentRuleList:source
                          completionHandler:^(WKContentRuleList *list, NSError *error) {
                            if (list != nil) {
                              [content addContentRuleList:list];
                              [view report:@[ @"rules", view.label, @"ready", name ]];
                            } else {
                              failed = YES;
                              [view report:@[ @"rules", view.label, @"failed", error.localizedDescription ?: name ]];
                            }
                            if (--outstanding == 0 && !failed && view.webView != nil) {
                              pudu_load_initial(view);
                            }
                          }];
  }
}

static void pudu_apply_bounds(PuduWebView *view, NSView *container) {
  if (view.fill) {
    view.webView.frame = container.bounds;
    view.webView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
  } else {
    view.webView.frame = view.frame;
    view.webView.autoresizingMask = NSViewNotSizable;
  }
}

static int32_t pudu_realize(PuduWebHost *host, PuduWebView *view) {
  PuduWebWindow *owner = host.windows[@(view.windowIdentifier)];
  if (owner == nil) {
    return pudu_view_refuse(host, PUDU_WEBVIEW_UNKNOWN, @"the view's window is closed");
  }
  WKWebViewConfiguration *configuration = [[WKWebViewConfiguration alloc] init];
  [configuration setURLSchemeHandler:view forURLScheme:@"pudu"];
  configuration.websiteDataStore = pudu_store(view);
  WKUserContentController *content = [[WKUserContentController alloc] init];
  for (WKUserScript *script in view.scripts) {
    [content addUserScript:script];
  }
  configuration.userContentController = content;
  if (view.devtools) {
    @try {
      [configuration.preferences setValue:@YES forKey:@"developerExtrasEnabled"];
    } @catch (NSException *exception) {
      (void)exception;
    }
  }
  WKWebView *webView = [[WKWebView alloc] initWithFrame:view.frame configuration:configuration];
  if (webView == nil) {
    return pudu_view_refuse(host, PUDU_WEBVIEW_PLATFORM, @"the WebView could not be created");
  }
  if (@available(macOS 13.3, *)) {
    webView.inspectable = view.devtools;
  }
  webView.navigationDelegate = view;
  webView.UIDelegate = view;
  if (view.userAgent.length > 0) {
    webView.customUserAgent = view.userAgent;
  }
  if (view.zoom > 0) {
    webView.pageZoom = view.zoom;
  }
  if (view.transparent) {
    @try {
      [webView setValue:@NO forKey:@"drawsBackground"];
    } @catch (NSException *exception) {
      (void)exception;
    }
  }
  view.webView = webView;
  [webView addObserver:view forKeyPath:@"title" options:NSKeyValueObservingOptionNew context:NULL];
  NSView *container = owner.window.contentView;
  pudu_apply_bounds(view, container);
  [container addSubview:webView];
  if (view.initialHTML == nil && view.initialURL != nil && [NSURL URLWithString:view.initialURL] == nil) {
    return pudu_view_refuse(host, PUDU_WEBVIEW_INVALID, @"the view's URL is not a URL");
  }
  pudu_compile_rules(view, content);
  return PUDU_WEBVIEW_DONE;
}

static int32_t pudu_create(PuduWebHost *host, int64_t identifier, pudu_field *fields, int count) {
  int64_t window = 0, x = 0, y = 0, width = 0, height = 0, fill = 0;
  if (count != 9 || pudu_field_int(fields[3], &window) != 0 || pudu_field_int(fields[4], &x) != 0 ||
      pudu_field_int(fields[5], &y) != 0 || pudu_field_int(fields[6], &width) != 0 ||
      pudu_field_int(fields[7], &height) != 0 || pudu_field_int(fields[8], &fill) != 0 ||
      width < 0 || height < 0) {
    return pudu_view_refuse(host, PUDU_WEBVIEW_MALFORMED, @"view create needs a window, a frame and a fill flag");
  }
  if (host.views[@(identifier)] != nil) {
    return pudu_view_refuse(host, PUDU_WEBVIEW_INVALID, @"view id is already in use");
  }
  if (host.windows[@(window)] == nil) {
    return pudu_view_refuse(host, PUDU_WEBVIEW_UNKNOWN, @"view create names a window that is not open");
  }
  PuduWebView *view = [[PuduWebView alloc] init];
  view.identifier = identifier;
  view.windowIdentifier = window;
  view.frame = NSMakeRect(x, y, width, height);
  view.fill = fill != 0;
  view.scripts = [NSMutableArray array];
  view.allowed = [NSMutableArray array];
  view.ruleSources = [NSMutableArray array];
  host.views[@(identifier)] = view;
  return PUDU_WEBVIEW_DONE;
}

/* Records that are only meaningful before the WebView exists. */
static int32_t pudu_configure(PuduWebHost *host, PuduWebView *view, NSString *verb, pudu_field *fields, int count) {
  NSString *value = count > 3 ? pudu_field_string(fields[3]) : nil;
  if (count > 3 && value == nil) {
    return pudu_view_refuse(host, PUDU_WEBVIEW_MALFORMED, [verb stringByAppendingString:@" is not UTF-8"]);
  }
  if ([verb isEqualToString:@"url"] && count == 4) {
    view.initialURL = value;
  } else if ([verb isEqualToString:@"html"] && count == 4) {
    view.initialHTML = value;
  } else if ([verb isEqualToString:@"devtools"] && count == 4) {
    view.devtools = [value isEqualToString:@"1"];
  } else if ([verb isEqualToString:@"user-agent"] && count == 4) {
    view.userAgent = value;
  } else if ([verb isEqualToString:@"zoom"] && count == 4) {
    view.zoom = value.doubleValue / 1000.0;
  } else if ([verb isEqualToString:@"data-store"] && count == 4) {
    view.dataStore = value;
  } else if ([verb isEqualToString:@"ephemeral"] && count == 3) {
    view.ephemeral = YES;
  } else if ([verb isEqualToString:@"transparent"] && count == 3) {
    view.transparent = YES;
  } else if ([verb isEqualToString:@"navigation-allow"] && count == 4) {
    [view.allowed addObject:value];
  } else if ([verb isEqualToString:@"rules"] && count == 4) {
    [view.ruleSources addObject:value];
  } else if ([verb isEqualToString:@"style"] && count == 4) {
    [view.scripts addObject:pudu_style_script(value)];
  } else if ([verb isEqualToString:@"script"] && count == 6) {
    NSString *time = pudu_field_string(fields[4]);
    NSString *frames = pudu_field_string(fields[5]);
    WKUserScriptInjectionTime when = [time isEqualToString:@"end"] ? WKUserScriptInjectionTimeAtDocumentEnd
                                                                   : WKUserScriptInjectionTimeAtDocumentStart;
    [view.scripts addObject:[[WKUserScript alloc] initWithSource:value
                                                   injectionTime:when
                                                forMainFrameOnly:![frames isEqualToString:@"all"]]];
  } else {
    return pudu_view_refuse(host, PUDU_WEBVIEW_MALFORMED, [@"unknown view configuration " stringByAppendingString:verb]);
  }
  return PUDU_WEBVIEW_DONE;
}

static void pudu_show_inspector(WKWebView *webView, BOOL show) {
  id inspector = [webView valueForKey:@"_inspector"];
  SEL selector = NSSelectorFromString(show ? @"show" : @"close");
  if (inspector == nil || ![inspector respondsToSelector:selector]) {
    [NSException raise:@"PuduInspector" format:@"the inspector cannot be opened programmatically"];
  }
  ((void (*)(id, SEL))objc_msgSend)(inspector, selector);
}

/* Commands applied to a realized WebView. */
static int32_t pudu_operate(PuduWebHost *host, PuduWebView *view, NSString *verb, pudu_field *fields, int count) {
  WKWebView *webView = view.webView;
  NSString *value = count > 3 ? pudu_field_string(fields[3]) : nil;
  if ([verb isEqualToString:@"navigate"] && count == 4) {
    NSURL *url = [NSURL URLWithString:value ?: @""];
    if (url == nil) {
      return pudu_view_refuse(host, PUDU_WEBVIEW_INVALID, @"navigate needs a URL");
    }
    [webView loadRequest:[NSURLRequest requestWithURL:url]];
  } else if ([verb isEqualToString:@"html"] && count == 4) {
    [webView loadHTMLString:value ?: @"" baseURL:[NSURL URLWithString:@"pudu://app/"]];
  } else if ([verb isEqualToString:@"reload"]) {
    [webView reload];
  } else if ([verb isEqualToString:@"back"]) {
    [webView goBack];
  } else if ([verb isEqualToString:@"forward"]) {
    [webView goForward];
  } else if ([verb isEqualToString:@"stop"]) {
    [webView stopLoading];
  } else if ([verb isEqualToString:@"eval"] && count == 5) {
    NSString *ticket = value;
    NSString *source = pudu_field_string(fields[4]) ?: @"";
    [webView evaluateJavaScript:source completionHandler:^(id result, NSError *error) {
      if (error != nil) {
        [view report:@[ @"eval", view.label, ticket, @"error", error.localizedDescription ?: @"failed" ]];
      } else {
        [view report:@[ @"eval", view.label, ticket, @"ok", pudu_text(result) ]];
      }
    }];
  } else if ([verb isEqualToString:@"bounds"] && count == 7) {
    int64_t x = 0, y = 0, width = 0, height = 0;
    if (pudu_field_int(fields[3], &x) != 0 || pudu_field_int(fields[4], &y) != 0 ||
        pudu_field_int(fields[5], &width) != 0 || pudu_field_int(fields[6], &height) != 0) {
      return pudu_view_refuse(host, PUDU_WEBVIEW_MALFORMED, @"bounds needs four numbers");
    }
    view.fill = NO;
    view.frame = NSMakeRect(x, y, width, height);
    pudu_apply_bounds(view, webView.superview);
  } else if ([verb isEqualToString:@"zoom"] && count == 4) {
    webView.pageZoom = value.doubleValue / 1000.0;
  } else if ([verb isEqualToString:@"user-agent"] && count == 4) {
    webView.customUserAgent = value;
  } else if ([verb isEqualToString:@"devtools-open"] || [verb isEqualToString:@"devtools-close"]) {
    @try {
      pudu_show_inspector(webView, [verb isEqualToString:@"devtools-open"]);
    } @catch (NSException *exception) {
      return pudu_view_refuse(host, PUDU_WEBVIEW_UNSUPPORTED, exception.reason ?: @"no inspector");
    }
  } else if ([verb isEqualToString:@"show"]) {
    webView.hidden = NO;
  } else if ([verb isEqualToString:@"hide"]) {
    webView.hidden = YES;
  } else if ([verb isEqualToString:@"focus"]) {
    [webView.window makeFirstResponder:webView];
  } else if ([verb isEqualToString:@"close"]) {
    [view detach];
    [host.views removeObjectForKey:@(view.identifier)];
  } else {
    return pudu_view_refuse(host, PUDU_WEBVIEW_MALFORMED, [@"unknown view command " stringByAppendingString:verb]);
  }
  return PUDU_WEBVIEW_DONE;
}

int32_t pudu_webview_view_command(PuduWebHost *host, pudu_field *fields, int count) {
  int64_t identifier = 0;
  if (count < 3 || pudu_field_int(fields[1], &identifier) != 0) {
    return pudu_view_refuse(host, PUDU_WEBVIEW_MALFORMED, @"view record needs an id and a verb");
  }
  NSString *verb = pudu_field_string(fields[2]) ?: @"";
  if ([verb isEqualToString:@"create"]) {
    return pudu_create(host, identifier, fields, count);
  }
  PuduWebView *view = host.views[@(identifier)];
  if (view == nil) {
    return pudu_view_refuse(host, PUDU_WEBVIEW_UNKNOWN, [NSString stringWithFormat:@"view %lld does not exist", identifier]);
  }
  if ([verb isEqualToString:@"realize"]) {
    if (view.webView != nil) {
      return pudu_view_refuse(host, PUDU_WEBVIEW_INVALID, @"the view is already realized");
    }
    return pudu_realize(host, view);
  }
  if (view.webView == nil) {
    if ([verb isEqualToString:@"close"]) {
      [host.views removeObjectForKey:@(identifier)];
      return PUDU_WEBVIEW_DONE;
    }
    return pudu_configure(host, view, verb, fields, count);
  }
  return pudu_operate(host, view, verb, fields, count);
}
