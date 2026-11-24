#ifndef PUDU_IOS_COMPOSE_H
#define PUDU_IOS_COMPOSE_H

/* System sheets that finish or not: the share sheet with a file, the event
   editor, and the mail and message composers. Each answers once under its
   tag: SHARED for a file, as for text; COMPLETED with 1 when the person saved
   or sent, 0 when they cancelled or the sheet cannot open. REVIEW asks for
   the rating prompt, which the platform may decline to show. */
#import <EventKit/EventKit.h>
#import <EventKitUI/EventKitUI.h>
#import <MessageUI/MessageUI.h>
#import <StoreKit/StoreKit.h>
#import <UIKit/UIKit.h>
#include <stdint.h>
#include "pudu_ios_events.h"
#include "pudu_ios_media.h"
#include "pudu_ios_stream.h"

/* Answers each sheet's outcome under the tag it was opened with. */
@interface PuduSheets : NSObject <EKEventEditViewDelegate, MFMailComposeViewControllerDelegate, MFMessageComposeViewControllerDelegate>
@property (strong, nonatomic) NSMapTable<id, NSNumber *> *tags;
@property (strong, nonatomic) EKEventStore *store;
@end

@implementation PuduSheets
- (void)finish:(UIViewController *)sheet done:(BOOL)done {
  NSNumber *tag = [self.tags objectForKey:sheet];
  [self.tags removeObjectForKey:sheet];
  [sheet dismissViewControllerAnimated:YES completion:nil];
  pudu_queue(PUDU_UI_COMPLETED, tag.integerValue, nil, done ? 1 : 0);
}
- (void)eventEditViewController:(EKEventEditViewController *)controller didCompleteWithAction:(EKEventEditViewAction)action {
  [self finish:controller done:action == EKEventEditViewActionSaved];
}
- (void)mailComposeController:(MFMailComposeViewController *)controller didFinishWithResult:(MFMailComposeResult)result error:(NSError *)error {
  (void)error;
  [self finish:controller done:result == MFMailComposeResultSent];
}
- (void)messageComposeViewController:(MFMessageComposeViewController *)controller didFinishWithResult:(MessageComposeResult)result {
  [self finish:controller done:result == MessageComposeResultSent];
}
@end

static PuduSheets *pudu_sheets;

static PuduSheets *pudu_sheets_shared(void) {
  if (pudu_sheets == nil) {
    pudu_sheets = [PuduSheets new];
    pudu_sheets.tags = [NSMapTable strongToStrongObjectsMapTable];
  }
  return pudu_sheets;
}

static void pudu_present_sheet(UIViewController *sheet, uint32_t tag) {
  [pudu_sheets_shared().tags setObject:@(tag) forKey:sheet];
  [pudu_media_presenter() presentViewController:sheet animated:YES completion:nil];
}

/* Recipients joined by commas, as the stream carries them. */
static NSArray<NSString *> *pudu_recipients(NSString *joined) {
  NSMutableArray *found = [NSMutableArray new];
  for (NSString *part in [joined componentsSeparatedByString:@","]) {
    NSString *trimmed = [part stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
    if (trimmed.length > 0) [found addObject:trimmed];
  }
  return found;
}

/* Unix seconds from a high signed word and a low word. */
static NSDate *pudu_date(pudu_reader *reader) {
  int32_t high = (int32_t)pudu_word(reader);
  uint32_t low = pudu_word(reader);
  return [NSDate dateWithTimeIntervalSince1970:(double)((int64_t)high * 4294967296LL + (int64_t)low)];
}

/* SHARE_FILE: the tag, then the path; a missing file answers false at once. */
static void pudu_do_share_file(pudu_reader *reader) {
  uint32_t tag = pudu_word(reader);
  NSString *path = pudu_text(reader);
  if (![NSFileManager.defaultManager fileExistsAtPath:path]) {
    pudu_queue(PUDU_UI_SHARED, tag, nil, 0);
    return;
  }
  UIViewController *presenter = pudu_media_presenter();
  UIActivityViewController *sheet = [[UIActivityViewController alloc] initWithActivityItems:@[ [NSURL fileURLWithPath:path] ] applicationActivities:nil];
  sheet.completionWithItemsHandler = ^(UIActivityType type, BOOL completed, NSArray *items, NSError *error) {
    (void)type;
    (void)items;
    (void)error;
    pudu_queue(PUDU_UI_SHARED, tag, nil, completed ? 1 : 0);
  };
  sheet.popoverPresentationController.sourceView = presenter.view;
  sheet.popoverPresentationController.sourceRect = CGRectMake(CGRectGetMidX(presenter.view.bounds), CGRectGetMidY(presenter.view.bounds), 1, 1);
  [presenter presentViewController:sheet animated:YES completion:nil];
}

/* REVIEW: no words. */
static void pudu_do_review(pudu_reader *reader) {
  (void)reader;
  UIWindowScene *scene = pudu_alert_presenter.view.window.windowScene;
  if (scene != nil) [SKStoreReviewController requestReviewInScene:scene];
}

/* ADD_EVENT: the tag, the start and end, the title, then the location. The
   editor runs outside the application, so no calendar permission is needed. */
static void pudu_do_add_event(pudu_reader *reader) {
  uint32_t tag = pudu_word(reader);
  NSDate *start = pudu_date(reader), *end = pudu_date(reader);
  NSString *title = pudu_text(reader), *location = pudu_text(reader);
  PuduSheets *sheets = pudu_sheets_shared();
  if (sheets.store == nil) sheets.store = [EKEventStore new];
  EKEvent *event = [EKEvent eventWithEventStore:sheets.store];
  event.title = title;
  event.location = location.length > 0 ? location : nil;
  event.startDate = start;
  event.endDate = [end compare:start] == NSOrderedDescending ? end : start;
  EKEventEditViewController *editor = [EKEventEditViewController new];
  editor.eventStore = sheets.store;
  editor.event = event;
  editor.editViewDelegate = sheets;
  pudu_present_sheet(editor, tag);
}

/* COMPOSE_MAIL: the tag, the recipients, the subject, then the body. */
static void pudu_do_compose_mail(pudu_reader *reader) {
  uint32_t tag = pudu_word(reader);
  NSString *to = pudu_text(reader), *subject = pudu_text(reader), *body = pudu_text(reader);
  if (![MFMailComposeViewController canSendMail]) {
    pudu_queue(PUDU_UI_COMPLETED, tag, nil, 0);
    return;
  }
  MFMailComposeViewController *composer = [MFMailComposeViewController new];
  composer.mailComposeDelegate = pudu_sheets_shared();
  [composer setToRecipients:pudu_recipients(to)];
  [composer setSubject:subject];
  [composer setMessageBody:body isHTML:NO];
  pudu_present_sheet(composer, tag);
}

/* COMPOSE_MESSAGE: the tag, the recipients, then the body. */
static void pudu_do_compose_message(pudu_reader *reader) {
  uint32_t tag = pudu_word(reader);
  NSString *to = pudu_text(reader), *body = pudu_text(reader);
  if (![MFMessageComposeViewController canSendText]) {
    pudu_queue(PUDU_UI_COMPLETED, tag, nil, 0);
    return;
  }
  MFMessageComposeViewController *composer = [MFMessageComposeViewController new];
  composer.messageComposeDelegate = pudu_sheets_shared();
  composer.recipients = pudu_recipients(to);
  composer.body = body;
  pudu_present_sheet(composer, tag);
}

#endif
