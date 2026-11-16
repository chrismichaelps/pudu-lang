#ifndef PUDU_IOS_TEXT_H
#define PUDU_IOS_TEXT_H

/* Text entry beyond the single-line field: a text area that grows with its
   text, and a search field. Both report CHANGED with their whole text and
   join keyboard avoidance when they take focus. */
#import <UIKit/UIKit.h>
#include "pudu_ios_controls.h"
#include "pudu_ios_events.h"
#include "pudu_ios_layout.h"

/* A text area that does not scroll inside the screen's own scrolling, so its
   height follows its text. It is its own delegate. */
@interface PuduTextArea : UITextView <UITextViewDelegate>
@end
@implementation PuduTextArea
- (void)textViewDidBeginEditing:(UITextView *)view { pudu_focus_field(view); }
- (void)textViewDidChange:(UITextView *)view { pudu_queue(PUDU_UI_CHANGED, view.tag, view.text, 0); }
@end

static UIView *pudu_make_text_area(void) {
  PuduTextArea *area = [PuduTextArea new];
  area.delegate = area;
  area.scrollEnabled = NO;
  area.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
  area.adjustsFontForContentSizeCategory = YES;
  area.layer.cornerRadius = 8;
  area.backgroundColor = UIColor.secondarySystemBackgroundColor;
  [area.widthAnchor constraintGreaterThanOrEqualToConstant:220].active = YES;
  [area.heightAnchor constraintGreaterThanOrEqualToConstant:88].active = YES;
  return area;
}

/* A text area already showing the text is left alone, so typing keeps its place. */
static void pudu_text_area_text(UIView *view, NSString *text) {
  UITextView *area = (UITextView *)view;
  if (![area.text isEqualToString:text]) area.text = text;
}

static void pudu_text_area_paint(UIView *view, UIColor *color) { ((UITextView *)view).textColor = color; }
static void pudu_text_area_style(UIView *view, UIFont *font) { ((UITextView *)view).font = font; }

static void pudu_text_area_fill(UIView *view, NSString *text) {
  PuduTextArea *area = (PuduTextArea *)view;
  area.text = text;
  [area textViewDidChange:area];
}

/* The search field is a text field: the field's setters and events apply. */
static UIView *pudu_make_search(void) {
  UISearchTextField *search = [UISearchTextField new];
  [search.widthAnchor constraintGreaterThanOrEqualToConstant:220].active = YES;
  [search addTarget:pudu_target action:@selector(focused:) forControlEvents:UIControlEventEditingDidBegin];
  [search addTarget:pudu_target action:@selector(edited:) forControlEvents:UIControlEventEditingChanged];
  return search;
}

#endif
