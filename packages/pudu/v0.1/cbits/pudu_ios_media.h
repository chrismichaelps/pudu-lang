#ifndef PUDU_IOS_MEDIA_H
#define PUDU_IOS_MEDIA_H

/* The in-app browser, speech and the photo picker. Each request answers
   exactly once under its tag: BROWSED when the browser closes, SPOKE when an
   utterance finishes or is stopped, IMAGE_PICKED with the path of a copy of
   the picked image or with nothing when the person cancels. */
#import <AVFoundation/AVFoundation.h>
#import <PhotosUI/PhotosUI.h>
#import <SafariServices/SafariServices.h>
#import <UIKit/UIKit.h>
#include <stdint.h>
#include <stdio.h>
#include "pudu_ios_events.h"
#include "pudu_ios_feedback.h"
#include "pudu_ios_notify.h"
#include "pudu_ios_stream.h"

/* How many SPOKE events were queued, for the services self-test. */
static unsigned pudu_spoke_count;

/* The controller new sheets present from: the topmost one shown. */
static UIViewController *pudu_media_presenter(void) {
  UIViewController *presenter = pudu_alert_presenter;
  while (presenter.presentedViewController != nil) presenter = presenter.presentedViewController;
  return presenter;
}

/* Answers each sheet's outcome under the tag it was opened with. */
@interface PuduMedia : NSObject <SFSafariViewControllerDelegate, AVSpeechSynthesizerDelegate, PHPickerViewControllerDelegate>
@property (strong, nonatomic) NSMapTable<id, NSNumber *> *tags;
@property (strong, nonatomic) AVSpeechSynthesizer *speech;
@end

@implementation PuduMedia
- (NSInteger)take:(id)key {
  NSNumber *tag = [self.tags objectForKey:key];
  [self.tags removeObjectForKey:key];
  return tag.integerValue;
}
- (void)safariViewControllerDidFinish:(SFSafariViewController *)controller {
  pudu_queue(PUDU_UI_BROWSED, [self take:controller], nil, 0);
}
- (void)speechSynthesizer:(AVSpeechSynthesizer *)synthesizer didFinishSpeechUtterance:(AVSpeechUtterance *)utterance {
  (void)synthesizer;
  pudu_spoke_count++;
  pudu_queue(PUDU_UI_SPOKE, [self take:utterance], nil, 1);
}
- (void)speechSynthesizer:(AVSpeechSynthesizer *)synthesizer didCancelSpeechUtterance:(AVSpeechUtterance *)utterance {
  (void)synthesizer;
  pudu_spoke_count++;
  pudu_queue(PUDU_UI_SPOKE, [self take:utterance], nil, 0);
}
/* The picked image's file is valid only inside the handler, so it is copied
   into the temporary directory before the answer is queued. */
- (void)picker:(PHPickerViewController *)picker didFinishPicking:(NSArray<PHPickerResult *> *)results {
  NSInteger tag = [self take:picker];
  [picker dismissViewControllerAnimated:YES completion:nil];
  NSItemProvider *provider = results.firstObject.itemProvider;
  if (provider == nil || ![provider hasItemConformingToTypeIdentifier:@"public.image"]) {
    pudu_queue(PUDU_UI_IMAGE_PICKED, tag, @"", 0);
    return;
  }
  [provider loadFileRepresentationForTypeIdentifier:@"public.image" completionHandler:^(NSURL *url, NSError *error) {
    (void)error;
    NSString *copied = nil;
    if (url != nil) {
      NSString *name = [NSString stringWithFormat:@"pudu-image-%@.%@", NSUUID.UUID.UUIDString, url.pathExtension.length > 0 ? url.pathExtension : @"img"];
      NSURL *target = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:name]];
      if ([NSFileManager.defaultManager copyItemAtURL:url toURL:target error:nil]) copied = target.path;
    }
    dispatch_async(dispatch_get_main_queue(), ^{ pudu_queue(PUDU_UI_IMAGE_PICKED, tag, copied ?: @"", copied != nil ? 1 : 0); });
  }];
}
@end

static PuduMedia *pudu_media;

static PuduMedia *pudu_media_shared(void) {
  if (pudu_media == nil) {
    pudu_media = [PuduMedia new];
    pudu_media.tags = [NSMapTable strongToStrongObjectsMapTable];
  }
  return pudu_media;
}

/* BROWSE: the tag, then the URL. A URL without an http or https scheme
   cannot open in the browser and answers at once. */
static void pudu_do_browse(pudu_reader *reader) {
  uint32_t tag = pudu_word(reader);
  NSURL *url = [NSURL URLWithString:pudu_text(reader)];
  NSString *scheme = url.scheme.lowercaseString;
  if (url == nil || !([scheme isEqualToString:@"http"] || [scheme isEqualToString:@"https"])) {
    pudu_queue(PUDU_UI_BROWSED, tag, nil, 0);
    return;
  }
  SFSafariViewController *browser = [[SFSafariViewController alloc] initWithURL:url];
  browser.delegate = pudu_media_shared();
  [pudu_media.tags setObject:@(tag) forKey:browser];
  [pudu_media_presenter() presentViewController:browser animated:YES completion:nil];
}

/* SPEAK: the tag, the rate in percent, the language tag, then the text. */
static void pudu_do_speak(pudu_reader *reader) {
  uint32_t tag = pudu_word(reader), rate = pudu_word(reader);
  NSString *language = pudu_text(reader), *text = pudu_text(reader);
  PuduMedia *media = pudu_media_shared();
  if (media.speech == nil) {
    media.speech = [AVSpeechSynthesizer new];
    media.speech.delegate = media;
  }
  AVSpeechUtterance *utterance = [AVSpeechUtterance speechUtteranceWithString:text];
  float paced = AVSpeechUtteranceDefaultSpeechRate * (float)rate / 100.0f;
  utterance.rate = MIN(MAX(paced, AVSpeechUtteranceMinimumSpeechRate), AVSpeechUtteranceMaximumSpeechRate);
  if (language.length > 0) utterance.voice = [AVSpeechSynthesisVoice voiceWithLanguage:language];
  [media.tags setObject:@(tag) forKey:utterance];
  [media.speech speakUtterance:utterance];
}

/* HUSH: no words; each queued utterance answers as stopped. */
static void pudu_do_hush(pudu_reader *reader) {
  (void)reader;
  [pudu_media.speech stopSpeakingAtBoundary:AVSpeechBoundaryImmediate];
}

/* PICK_IMAGE: the tag. */
static void pudu_do_pick_image(pudu_reader *reader) {
  uint32_t tag = pudu_word(reader);
  PHPickerConfiguration *configuration = [PHPickerConfiguration new];
  configuration.filter = PHPickerFilter.imagesFilter;
  configuration.selectionLimit = 1;
  PHPickerViewController *picker = [[PHPickerViewController alloc] initWithConfiguration:configuration];
  picker.delegate = pudu_media_shared();
  [pudu_media.tags setObject:@(tag) forKey:picker];
  [pudu_media_presenter() presentViewController:picker animated:YES completion:nil];
}

/* The services self-test: an authentication or an utterance still waiting
   after two seconds is cancelled, as a person would cancel it; once authentication, the battery and
   speech have each answered, or after fifteen seconds, it reports which did
   and stops. */
static void pudu_test_services(void (^done)(void)) {
  __block int waited = 0;
  __block void (^check)(void);
  check = ^{
    if (waited == 20 && pudu_authenticated_count == 0) pudu_authentication_cancel();
    if (waited == 20 && pudu_spoke_count == 0) [pudu_media.speech stopSpeakingAtBoundary:AVSpeechBoundaryImmediate];
    BOOL settled = pudu_authenticated_count > 0 && pudu_powered_count > 0 && pudu_spoke_count > 0;
    if (!settled && waited++ < 150) {
      dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 100 * NSEC_PER_MSEC), dispatch_get_main_queue(), check);
      return;
    }
    printf("PUDU_SERVICES authenticated %s powered %s spoke %s\n", pudu_authenticated_count > 0 ? "yes" : "no",
           pudu_powered_count > 0 ? "yes" : "no", pudu_spoke_count > 0 ? "yes" : "no");
    fflush(stdout);
    check = nil;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 300 * NSEC_PER_MSEC), dispatch_get_main_queue(), done);
  };
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 300 * NSEC_PER_MSEC), dispatch_get_main_queue(), check);
}

#endif
