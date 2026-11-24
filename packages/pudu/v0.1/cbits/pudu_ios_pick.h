#ifndef PUDU_IOS_PICK_H
#define PUDU_IOS_PICK_H

/* Pickers and system touches. Each picker answers exactly once under its
   tag: CONTACT_PICKED with the shared contact or nothing, FILED with the
   path of a copy in the temporary directory (a document, a photo taken, a
   finished recording) or nothing. BADGE needs the notifications kind; SECURE
   has no control on this platform and is ignored; TOAST fades a label over
   the root view. */
#import <AVFoundation/AVFoundation.h>
#import <Contacts/Contacts.h>
#import <ContactsUI/ContactsUI.h>
#import <UIKit/UIKit.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
#include <stdint.h>
#include "pudu_ios_events.h"
#include "pudu_ios_media.h"
#include "pudu_ios_stream.h"
#if PUDU_PERMISSION_NOTIFICATIONS
#import <UserNotifications/UserNotifications.h>
#endif

/* A file in the temporary directory with a fresh name and `extension`. */
static NSURL *pudu_temporary_file(NSString *extension) {
  NSString *name = [NSString stringWithFormat:@"pudu-%@.%@", NSUUID.UUID.UUIDString, extension.length > 0 ? extension : @"bin"];
  return [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:name]];
}

static void pudu_filed(NSInteger tag, NSString *path) { pudu_queue(PUDU_UI_FILED, tag, path ?: @"", path != nil ? 1 : 0); }

/* Answers each picker's outcome under the tag it was opened with. */
@interface PuduPickers : NSObject <CNContactPickerDelegate, UIDocumentPickerDelegate, UIImagePickerControllerDelegate,
                                   UINavigationControllerDelegate>
@property (strong, nonatomic) NSMapTable<id, NSNumber *> *tags;
@property (strong, nonatomic) AVAudioRecorder *recorder;
@end

@implementation PuduPickers
- (NSInteger)take:(id)key {
  NSNumber *tag = [self.tags objectForKey:key];
  [self.tags removeObjectForKey:key];
  return tag.integerValue;
}
- (void)contactPicker:(CNContactPickerViewController *)picker didSelectContact:(CNContact *)contact {
  NSMutableArray *phones = [NSMutableArray new], *emails = [NSMutableArray new];
  for (CNLabeledValue<CNPhoneNumber *> *phone in contact.phoneNumbers) [phones addObject:phone.value.stringValue];
  for (CNLabeledValue<NSString *> *email in contact.emailAddresses) [emails addObject:email.value];
  NSString *name = [CNContactFormatter stringFromContact:contact style:CNContactFormatterStyleFullName] ?: @"";
  NSString *text = [@[ [name stringByReplacingOccurrencesOfString:@"\n" withString:@" "], [phones componentsJoinedByString:@","],
                       [emails componentsJoinedByString:@","] ] componentsJoinedByString:@"\n"];
  pudu_queue(PUDU_UI_CONTACT_PICKED, [self take:picker], text, 1);
}
- (void)contactPickerDidCancel:(CNContactPickerViewController *)picker {
  pudu_queue(PUDU_UI_CONTACT_PICKED, [self take:picker], @"", 0);
}
/* A copied document is the application's own; it is moved to a fresh name. */
- (void)documentPicker:(UIDocumentPickerViewController *)picker didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
  NSInteger tag = [self take:picker];
  NSURL *source = urls.firstObject, *target = pudu_temporary_file(source.pathExtension);
  BOOL moved = source != nil && [NSFileManager.defaultManager moveItemAtURL:source toURL:target error:nil];
  pudu_filed(tag, moved ? target.path : nil);
}
- (void)documentPickerWasCancelled:(UIDocumentPickerViewController *)picker { pudu_filed([self take:picker], nil); }
- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary<UIImagePickerControllerInfoKey, id> *)info {
  NSInteger tag = [self take:picker];
  [picker dismissViewControllerAnimated:YES completion:nil];
  UIImage *photo = info[UIImagePickerControllerOriginalImage];
  NSURL *target = pudu_temporary_file(@"jpg");
  BOOL written = photo != nil && [UIImageJPEGRepresentation(photo, 0.9) writeToURL:target atomically:YES];
  pudu_filed(tag, written ? target.path : nil);
}
- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
  NSInteger tag = [self take:picker];
  [picker dismissViewControllerAnimated:YES completion:nil];
  pudu_filed(tag, nil);
}
@end

static PuduPickers *pudu_pickers;

static PuduPickers *pudu_pickers_shared(void) {
  if (pudu_pickers == nil) {
    pudu_pickers = [PuduPickers new];
    pudu_pickers.tags = [NSMapTable strongToStrongObjectsMapTable];
  }
  return pudu_pickers;
}

static void pudu_present_picker(UIViewController *picker, uint32_t tag) {
  [pudu_pickers_shared().tags setObject:@(tag) forKey:picker];
  [pudu_media_presenter() presentViewController:picker animated:YES completion:nil];
}

/* PICK_CONTACT: the tag. */
static void pudu_do_pick_contact(pudu_reader *reader) {
  uint32_t tag = pudu_word(reader);
  CNContactPickerViewController *picker = [CNContactPickerViewController new];
  picker.delegate = pudu_pickers_shared();
  pudu_present_picker(picker, tag);
}

/* PICK_DOCUMENT: the tag, then comma-separated MIME types; none allows any. */
static void pudu_do_pick_document(pudu_reader *reader) {
  uint32_t tag = pudu_word(reader);
  NSString *listed = pudu_text(reader);
  NSMutableArray<UTType *> *types = [NSMutableArray new];
  for (NSString *mime in [listed componentsSeparatedByString:@","]) {
    NSString *trimmed = [mime stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
    if (trimmed.length == 0) continue;
    UTType *type = [trimmed hasSuffix:@"/*"] ? ([trimmed hasPrefix:@"image/"] ? UTTypeImage : [trimmed hasPrefix:@"video/"] ? UTTypeMovie
                                                : [trimmed hasPrefix:@"audio/"] ? UTTypeAudio : [trimmed hasPrefix:@"text/"] ? UTTypeText : UTTypeItem)
                                             : [UTType typeWithMIMEType:trimmed];
    if (type != nil) [types addObject:type];
  }
  if (types.count == 0) [types addObject:UTTypeItem];
  UIDocumentPickerViewController *picker = [[UIDocumentPickerViewController alloc] initForOpeningContentTypes:types asCopy:YES];
  picker.delegate = pudu_pickers_shared();
  pudu_present_picker(picker, tag);
}

/* TAKE_PHOTO: the tag. A device without a camera answers no file at once. */
static void pudu_do_take_photo(pudu_reader *reader) {
  uint32_t tag = pudu_word(reader);
  if (![UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera]) {
    pudu_filed(tag, nil);
    return;
  }
  UIImagePickerController *picker = [UIImagePickerController new];
  picker.sourceType = UIImagePickerControllerSourceTypeCamera;
  picker.delegate = pudu_pickers_shared();
  pudu_present_picker(picker, tag);
}

/* RECORD: the tag, then 1 to start or 0 to stop; stopping answers the file. */
static void pudu_do_record(pudu_reader *reader) {
  uint32_t tag = pudu_word(reader), on = pudu_word(reader);
  if (on > 1) pudu_stream_defect("set recording to", on);
  PuduPickers *pickers = pudu_pickers_shared();
  if (on == 0) {
    AVAudioRecorder *recorder = pickers.recorder;
    pickers.recorder = nil;
    [recorder stop];
    pudu_filed(tag, recorder != nil ? recorder.url.path : nil);
    return;
  }
  [pickers.recorder stop];
  AVAudioSession *session = AVAudioSession.sharedInstance;
  [session setCategory:AVAudioSessionCategoryPlayAndRecord error:nil];
  [session setActive:YES error:nil];
  NSDictionary *settings = @{ AVFormatIDKey : @(kAudioFormatMPEG4AAC), AVSampleRateKey : @44100, AVNumberOfChannelsKey : @1 };
  AVAudioRecorder *recorder = [[AVAudioRecorder alloc] initWithURL:pudu_temporary_file(@"m4a") settings:settings error:nil];
  if (recorder == nil || ![recorder record]) {
    pudu_filed(tag, nil);
    return;
  }
  pickers.recorder = recorder;
}

/* BADGE: the count. */
static void pudu_do_badge(pudu_reader *reader) {
  uint32_t count = pudu_word(reader);
#if PUDU_PERMISSION_NOTIFICATIONS
  [UNUserNotificationCenter.currentNotificationCenter setBadgeCount:count withCompletionHandler:nil];
#else
  (void)count;
#endif
}

/* SECURE: read and ignored. */
static void pudu_do_secure(pudu_reader *reader) {
  uint32_t on = pudu_word(reader);
  if (on > 1) pudu_stream_defect("set secure screen to", on);
}

/* TOAST: the text, shown near the bottom for two seconds, then faded out. */
static void pudu_do_toast(pudu_reader *reader) {
  NSString *text = pudu_text(reader);
  UIView *root = pudu_alert_presenter.view;
  UILabel *label = [UILabel new];
  label.text = text;
  label.numberOfLines = 0;
  label.textAlignment = NSTextAlignmentCenter;
  label.textColor = UIColor.systemBackgroundColor;
  label.backgroundColor = [UIColor.labelColor colorWithAlphaComponent:0.85];
  label.layer.cornerRadius = 12;
  label.clipsToBounds = YES;
  label.translatesAutoresizingMaskIntoConstraints = NO;
  [root addSubview:label];
  [NSLayoutConstraint activateConstraints:@[
    [label.centerXAnchor constraintEqualToAnchor:root.centerXAnchor],
    [label.bottomAnchor constraintEqualToAnchor:root.safeAreaLayoutGuide.bottomAnchor constant:-32],
    [label.widthAnchor constraintLessThanOrEqualToAnchor:root.widthAnchor multiplier:0.8],
    [label.heightAnchor constraintGreaterThanOrEqualToConstant:44],
  ]];
  [UIView animateWithDuration:0.3 delay:2.0 options:0 animations:^{ label.alpha = 0; } completion:^(BOOL finished) {
    (void)finished;
    [label removeFromSuperview];
  }];
}

#endif
