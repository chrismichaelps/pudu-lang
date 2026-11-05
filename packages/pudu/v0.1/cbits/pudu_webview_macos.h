#ifndef PUDU_WEBVIEW_MACOS_H
#define PUDU_WEBVIEW_MACOS_H

#import <AppKit/AppKit.h>
#import <WebKit/WebKit.h>

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

#endif
