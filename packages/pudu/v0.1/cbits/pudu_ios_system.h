#ifndef PUDU_IOS_SYSTEM_H
#define PUDU_IOS_SYSTEM_H

/* What the program asks of the system rather than of a control: opening a
   URL in the app that handles it, the share sheet, the clipboard and the
   status bar. Each request that has an outcome reports it once: OPENED
   whether an app opened the URL, SHARED whether the person shared, PASTED the
   clipboard's text. */
#import <UIKit/UIKit.h>
#include <stdint.h>
#include <stdio.h>
#include "pudu_ios_events.h"
#include "pudu_ios_feedback.h"
#include "pudu_ios_nodes.h"
#include "pudu_ios_scene.h"
#include "pudu_ios_stream.h"

enum { PUDU_STATUS_STYLES = 3 };

/* The share sheet on screen, kept so the self-test can close it. */
static UIActivityViewController *pudu_sharing;

/* OPEN: the tag, then the URL. A URL the platform cannot read reports false. */
static void pudu_do_open(pudu_reader *reader) {
  uint32_t tag = pudu_word(reader);
  NSURL *url = [NSURL URLWithString:pudu_text(reader)];
  if (url == nil || url.scheme == nil) {
    pudu_queue(PUDU_UI_OPENED, tag, nil, 0);
    return;
  }
  [UIApplication.sharedApplication openURL:url options:@{} completionHandler:^(BOOL opened) {
    pudu_queue(PUDU_UI_OPENED, tag, nil, opened ? 1 : 0);
  }];
}

/* SHARE: the tag, then the text; the sheet anchors to the screen's center on
   an iPad, where it is a popover. */
static void pudu_do_share(pudu_reader *reader) {
  uint32_t tag = pudu_word(reader);
  NSString *text = pudu_text(reader);
  UIViewController *presenter = pudu_alert_presenter;
  while (presenter.presentedViewController != nil) presenter = presenter.presentedViewController;
  UIActivityViewController *sheet = [[UIActivityViewController alloc] initWithActivityItems:@[ text ] applicationActivities:nil];
  sheet.completionWithItemsHandler = ^(UIActivityType type, BOOL completed, NSArray *items, NSError *error) {
    (void)type;
    (void)items;
    (void)error;
    if (pudu_sharing == sheet) pudu_sharing = nil;
    pudu_queue(PUDU_UI_SHARED, tag, nil, completed ? 1 : 0);
  };
  sheet.popoverPresentationController.sourceView = presenter.view;
  sheet.popoverPresentationController.sourceRect = CGRectMake(CGRectGetMidX(presenter.view.bounds), CGRectGetMidY(presenter.view.bounds), 1, 1);
  pudu_sharing = sheet;
  [presenter presentViewController:sheet animated:YES completion:nil];
}

static void pudu_do_copy(pudu_reader *reader) { UIPasteboard.generalPasteboard.string = pudu_text(reader); }

static void pudu_do_paste(pudu_reader *reader) {
  uint32_t tag = pudu_word(reader);
  pudu_queue(PUDU_UI_PASTED, tag, UIPasteboard.generalPasteboard.string ?: @"", 0);
}

/* STATUS: the style code, then 1 to hide the bar or 0 to show it. */
static void pudu_do_status(pudu_reader *reader) {
  static const UIStatusBarStyle styles[PUDU_STATUS_STYLES] = { UIStatusBarStyleDefault, UIStatusBarStyleLightContent, UIStatusBarStyleDarkContent };
  uint32_t style = pudu_word(reader), hidden = pudu_word(reader);
  if (style >= PUDU_STATUS_STYLES) pudu_stream_defect("used unknown status bar style", style);
  if (hidden > 1) pudu_stream_defect("set the status bar hidden to", hidden);
  pudu_status_style = styles[style];
  pudu_status_hidden = hidden == 1;
  [pudu_alert_presenter setNeedsStatusBarAppearanceUpdate];
}

/* The system self-test: once the share sheet is up it reports it, closes it
   as a person cancelling would, reports the status bar, and stops. */
static void pudu_test_system(void (^done)(void)) {
  __block int waited = 0;
  __block void (^check)(void);
  check = ^{
    if (pudu_sharing == nil || pudu_sharing.presentingViewController == nil) {
      if (waited++ < 50) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 100 * NSEC_PER_MSEC), dispatch_get_main_queue(), check);
        return;
      }
      puts("PUDU_SYSTEM share never shown");
    } else {
      UIActivityViewController *sheet = pudu_sharing;
      puts("PUDU_SYSTEM share shown");
      [sheet dismissViewControllerAnimated:NO completion:nil];
      sheet.completionWithItemsHandler(nil, NO, nil, nil);
    }
    printf("PUDU_SYSTEM status %s %s\n", pudu_status_style == UIStatusBarStyleLightContent ? "light" : "other",
           pudu_status_hidden ? "hidden" : "shown");
    fflush(stdout);
    check = nil;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 500 * NSEC_PER_MSEC), dispatch_get_main_queue(), done);
  };
  check();
}

#endif
