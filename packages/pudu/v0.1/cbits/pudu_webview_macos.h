#ifndef PUDU_WEBVIEW_MACOS_H
#define PUDU_WEBVIEW_MACOS_H

#import <AppKit/AppKit.h>
#import <WebKit/WebKit.h>
#import <objc/message.h>

#include "pudu_webview.h"
#include "pudu_webview_records.h"

@class PuduWebHost;

/* A window's content view: flipped, so view frames are top-left. */
@interface PuduWebContent : NSView
@end

@interface PuduWebWindow : NSObject <NSWindowDelegate>
@property(nonatomic) int64_t identifier;
@property(nonatomic, strong) NSWindow *window;
@end

/* One request WebKit is waiting on. */
@interface PuduPendingRequest : NSObject
@property(nonatomic, strong) id<WKURLSchemeTask> task;
@property(nonatomic, strong) NSData *body;
@property(nonatomic) BOOL stopped;
@end

@interface PuduWebView : NSObject <WKNavigationDelegate, WKUIDelegate, WKURLSchemeHandler>
@property(nonatomic) int64_t identifier;
@property(nonatomic) int64_t windowIdentifier;
@property(nonatomic) NSRect frame;
@property(nonatomic) BOOL fill;
@property(nonatomic, strong) WKWebView *webView;
@property(nonatomic, strong) NSMutableArray<WKUserScript *> *scripts;
@property(nonatomic, strong) NSMutableArray<NSString *> *allowed;
@property(nonatomic, strong) NSMutableArray<NSString *> *ruleSources;
@property(nonatomic, copy) NSString *initialURL;
@property(nonatomic, copy) NSString *initialHTML;
@property(nonatomic, copy) NSString *userAgent;
@property(nonatomic, copy) NSString *dataStore;
@property(nonatomic) BOOL ephemeral;
@property(nonatomic) BOOL devtools;
@property(nonatomic) BOOL transparent;
@property(nonatomic) double zoom;
@property(nonatomic) BOOL fileDrop;
@property(nonatomic, strong) NSMutableDictionary<NSString *, NSString *> *windowActions;
/* Stops observing and removes the WebView from its window. */
- (void)detach;
@end

@interface PuduWebHost : NSObject
@property(nonatomic, strong) NSMutableDictionary<NSNumber *, PuduWebWindow *> *windows;
@property(nonatomic, strong) NSMutableDictionary<NSNumber *, PuduWebView *> *views;
@property(nonatomic, strong) NSMutableDictionary<NSNumber *, PuduPendingRequest *> *pending;
@property(nonatomic) int64_t nextRequest;
@property(nonatomic, copy) NSString *failure;
+ (PuduWebHost *)shared;
/* Queues one event of text fields and wakes a waiting pump. */
- (void)event:(NSArray<NSString *> *)fields;
/* Queues one event whose fields are raw bytes. */
- (void)eventData:(NSArray<NSData *> *)fields;
@end

/* Applies one view record (fields[0] is "view"); answers a status and sets
   the host's failure when it refuses. */
int32_t pudu_webview_view_command(PuduWebHost *host, pudu_field *fields, int count);

NSString *pudu_field_string(pudu_field field);

/* A WebView that can take file drops from the program instead of navigating to them. */
@interface PuduWebKitView : WKWebView
@property(nonatomic) int64_t viewIdentifier;
@property(nonatomic) BOOL dropEnabled;
@end

/* Window requests a page makes that must run inside the event that caused them. */
@interface PuduWindowMessages : NSObject <WKScriptMessageHandler>
@property(nonatomic, weak) PuduWebView *view;
@end

PuduWebKitView *pudu_webview_interactive_view(PuduWebView *view, WKWebViewConfiguration *configuration);
int32_t pudu_webview_window_permission(PuduWebHost *host, PuduWebView *view, pudu_field *fields, int count);
void pudu_report_window_state(PuduWebWindow *owner);
void pudu_report_window_scale(PuduWebWindow *owner);
NSString *pudu_theme_name(NSAppearance *appearance);
/* Window verbs beyond opening, sizing and closing; answers -3 for a verb it does not know. */
int32_t pudu_webview_window_extra(PuduWebHost *host, PuduWebWindow *owner, NSString *verb, pudu_field *fields, int count);
/* View verbs for the inspector, printing and stored data. */
int32_t pudu_webview_view_extra(PuduWebHost *host, PuduWebView *view, NSString *verb, pudu_field *fields, int count);

/* Applies one native-component record (fields[0] is "app" or "surface"). */
int32_t pudu_webview_native_command(PuduWebHost *host, pudu_field *fields, int count);

#endif
