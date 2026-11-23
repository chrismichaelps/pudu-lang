#ifndef PUDU_IOS_WEB_H
#define PUDU_IOS_WEB_H

/* Web pages and video as nodes, sounds as requests, keyboard dismissal and
   the back gesture. A source with an http or https scheme is remote,
   about:blank opens an empty page, and any other text names a file in the
   bundled assets. LOADED answers each load with the page node's tag; ENDED
   reports a video or sound that reached its end without looping. */
#import <AVFoundation/AVFoundation.h>
#import <UIKit/UIKit.h>
#import <WebKit/WebKit.h>
#include <stdint.h>
#include <stdio.h>
#include "pudu_ios_events.h"
#include "pudu_ios_feedback.h"
#include "pudu_ios_nodes.h"
#include "pudu_ios_stream.h"

/* How many LOADED events were queued, for the web self-test. */
static unsigned pudu_loaded_count;

/* The bundled assets directory, and a source resolved against it. */
static NSString *pudu_assets_root(void) { return [NSBundle.mainBundle.resourcePath stringByAppendingPathComponent:@"assets"]; }

static NSURL *pudu_source_url(NSString *source) {
  NSURL *url = [NSURL URLWithString:source];
  NSString *scheme = url.scheme.lowercaseString;
  if ([scheme isEqualToString:@"http"] || [scheme isEqualToString:@"https"] || [source isEqualToString:@"about:blank"]) return url;
  return [NSURL fileURLWithPath:[pudu_assets_root() stringByAppendingPathComponent:source]];
}

/* Reports each page load once, with the view's tag. */
@interface PuduPages : NSObject <WKNavigationDelegate>
@end
@implementation PuduPages
- (void)answer:(WKWebView *)view loaded:(BOOL)loaded {
  pudu_loaded_count++;
  pudu_queue(PUDU_UI_LOADED, view.tag, nil, loaded ? 1 : 0);
}
- (void)webView:(WKWebView *)view didFinishNavigation:(WKNavigation *)navigation {
  (void)navigation;
  [self answer:view loaded:YES];
}
- (void)webView:(WKWebView *)view didFailNavigation:(WKNavigation *)navigation withError:(NSError *)error {
  (void)navigation;
  (void)error;
  [self answer:view loaded:NO];
}
- (void)webView:(WKWebView *)view didFailProvisionalNavigation:(WKNavigation *)navigation withError:(NSError *)error {
  (void)navigation;
  (void)error;
  [self answer:view loaded:NO];
}
@end

static PuduPages *pudu_pages;

static UIView *pudu_make_web(void) {
  if (pudu_pages == nil) pudu_pages = [PuduPages new];
  WKWebView *view = [[WKWebView alloc] initWithFrame:CGRectZero configuration:[WKWebViewConfiguration new]];
  view.navigationDelegate = pudu_pages;
  view.translatesAutoresizingMaskIntoConstraints = NO;
  [view.heightAnchor constraintGreaterThanOrEqualToConstant:200].active = YES;
  return view;
}

/* LOAD: the node, then the URL. A bundled page may read the assets beside it. */
static void pudu_do_load(pudu_reader *reader) {
  uint32_t node = pudu_node_id(reader);
  NSString *source = pudu_text(reader);
  if (pudu_kinds[node].unsignedIntValue != PUDU_UI_WEB) pudu_stream_defect("loaded a page into a node that is not a web view:", node);
  WKWebView *view = pudu_nodes[node];
  NSURL *url = pudu_source_url(source);
  if (url.isFileURL) [view loadFileURL:url allowingReadAccessToURL:[NSURL fileURLWithPath:pudu_assets_root()]];
  else [view loadRequest:[NSURLRequest requestWithURL:url]];
}

/* A video view: its layer is the player's, fit inside the view's bounds. */
@interface PuduVideo : UIView
@property (strong, nonatomic) AVPlayer *player;
@property (nonatomic) BOOL looping;
@property (copy, nonatomic) NSString *source;
@end
@implementation PuduVideo
+ (Class)layerClass { return AVPlayerLayer.class; }
- (void)ended:(NSNotification *)note {
  if (note.object != self.player.currentItem) return;
  if (self.looping) {
    [self.player seekToTime:kCMTimeZero];
    [self.player play];
  } else {
    pudu_queue(PUDU_UI_ENDED, self.tag, nil, 0);
  }
}
@end

static UIView *pudu_make_video(void) {
  PuduVideo *view = [PuduVideo new];
  view.player = [AVPlayer new];
  ((AVPlayerLayer *)view.layer).player = view.player;
  ((AVPlayerLayer *)view.layer).videoGravity = AVLayerVideoGravityResizeAspect;
  view.translatesAutoresizingMaskIntoConstraints = NO;
  [view.heightAnchor constraintGreaterThanOrEqualToConstant:200].active = YES;
  [NSNotificationCenter.defaultCenter addObserver:view selector:@selector(ended:) name:AVPlayerItemDidPlayToEndTimeNotification object:nil];
  return view;
}

/* MEDIA: the node, playing, looping, then the source; a new source restarts. */
static void pudu_do_media(pudu_reader *reader) {
  uint32_t node = pudu_node_id(reader), playing = pudu_word(reader), looping = pudu_word(reader);
  NSString *source = pudu_text(reader);
  if (pudu_kinds[node].unsignedIntValue != PUDU_UI_VIDEO) pudu_stream_defect("set media on a node that is not a video:", node);
  if (playing > 1 || looping > 1) pudu_stream_defect("set a media flag to", playing > 1 ? playing : looping);
  PuduVideo *view = pudu_nodes[node];
  view.looping = looping == 1;
  if (![view.source isEqualToString:source]) {
    view.source = source;
    [view.player replaceCurrentItemWithPlayerItem:[AVPlayerItem playerItemWithURL:pudu_source_url(source)]];
  }
  if (playing == 1) [view.player play];
  else [view.player pause];
}

/* Sounds by tag, and whether each loops. */
static NSMutableDictionary<NSNumber *, AVPlayer *> *pudu_sounds;
static NSMutableSet<NSNumber *> *pudu_looping_sounds;

static void pudu_sound_ended(NSNotification *note) {
  for (NSNumber *tag in pudu_sounds.allKeys) {
    AVPlayer *player = pudu_sounds[tag];
    if (note.object != player.currentItem) continue;
    if ([pudu_looping_sounds containsObject:tag]) {
      [player seekToTime:kCMTimeZero];
      [player play];
    } else {
      [pudu_sounds removeObjectForKey:tag];
      pudu_queue(PUDU_UI_ENDED, tag.integerValue, nil, 0);
    }
  }
}

/* AUDIO: the tag, playing, looping, then the source. */
static void pudu_do_audio(pudu_reader *reader) {
  uint32_t tag = pudu_word(reader), playing = pudu_word(reader), looping = pudu_word(reader);
  NSString *source = pudu_text(reader);
  if (playing > 1 || looping > 1) pudu_stream_defect("set a media flag to", playing > 1 ? playing : looping);
  if (pudu_sounds == nil) {
    pudu_sounds = [NSMutableDictionary new];
    pudu_looping_sounds = [NSMutableSet new];
    [NSNotificationCenter.defaultCenter addObserverForName:AVPlayerItemDidPlayToEndTimeNotification object:nil queue:NSOperationQueue.mainQueue
                                                usingBlock:^(NSNotification *note) { pudu_sound_ended(note); }];
  }
  [pudu_sounds[@(tag)] pause];
  [pudu_sounds removeObjectForKey:@(tag)];
  [pudu_looping_sounds removeObject:@(tag)];
  if (playing == 0) return;
  AVPlayer *player = [AVPlayer playerWithURL:pudu_source_url(source)];
  pudu_sounds[@(tag)] = player;
  if (looping == 1) [pudu_looping_sounds addObject:@(tag)];
  [player play];
}

/* KEYBOARD: no words. */
static void pudu_do_keyboard(pudu_reader *reader) {
  (void)reader;
  [pudu_alert_presenter.view.window endEditing:YES];
}

/* BACK: read and ignored; the platform has no system back gesture outside
   navigation, whose own back is reported as a pop. */
static void pudu_do_back(pudu_reader *reader) {
  uint32_t on = pudu_word(reader);
  if (on > 1) pudu_stream_defect("set back handling to", on);
}

/* The web self-test: once a page has answered, or after ten seconds, it
   reports whether one did and stops. */
static void pudu_test_web(void (^done)(void)) {
  __block int waited = 0;
  __block void (^check)(void);
  check = ^{
    if (pudu_loaded_count == 0 && waited++ < 100) {
      dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 100 * NSEC_PER_MSEC), dispatch_get_main_queue(), check);
      return;
    }
    printf("PUDU_WEB loaded %s\n", pudu_loaded_count > 0 ? "yes" : "no");
    fflush(stdout);
    check = nil;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 300 * NSEC_PER_MSEC), dispatch_get_main_queue(), done);
  };
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 300 * NSEC_PER_MSEC), dispatch_get_main_queue(), check);
}

#endif
