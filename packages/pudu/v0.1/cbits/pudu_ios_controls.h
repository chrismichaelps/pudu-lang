#ifndef PUDU_IOS_CONTROLS_H
#define PUDU_IOS_CONTROLS_H

/* The platform controls of the iOS host: one factory per control kind, the
   setters each kind accepts, and what a self-test does to a kind and reads
   back. Controls report input by queueing events; nothing here reads the
   view stream. */
#import <UIKit/UIKit.h>
#include <stdint.h>
#include "pudu_ios_events.h"
#include "pudu_ios_layout.h"
#include "pudu_ios_list.h"
#include "pudu_ios_theme.h"

/* A toggle: its title beside the platform switch. */
@interface PuduToggle : UIStackView
@property (strong, nonatomic) UILabel *title;
@property (strong, nonatomic) UISwitch *control;
@end
@implementation PuduToggle
@end

@interface PuduTarget : NSObject
- (void)tapped:(UIButton *)sender;
- (void)edited:(UITextField *)sender;
- (void)focused:(UITextField *)sender;
- (void)switched:(UISwitch *)sender;
@end
@implementation PuduTarget
- (void)tapped:(UIButton *)sender { pudu_queue(PUDU_UI_TAPPED, sender.tag, nil, 0); }
- (void)focused:(UITextField *)sender { pudu_focus_field(sender); }
- (void)edited:(UITextField *)sender { pudu_queue(PUDU_UI_CHANGED, sender.tag, sender.text, 0); }
- (void)switched:(UISwitch *)sender { pudu_queue(sender.on ? PUDU_UI_SWITCHED_ON : PUDU_UI_SWITCHED_OFF, sender.tag, nil, 0); }
@end
static PuduTarget *pudu_target;

/* Factories: one control per kind. */
static UIView *pudu_make_label(void) {
  UILabel *label = [UILabel new];
  label.font = [UIFont preferredFontForTextStyle:UIFontTextStyleTitle1];
  label.adjustsFontForContentSizeCategory = YES;
  return label;
}

static UIView *pudu_make_button(void) {
  UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
  [button addTarget:pudu_target action:@selector(tapped:) forControlEvents:UIControlEventTouchUpInside];
  return button;
}

static UIStackView *pudu_make_group(UILayoutConstraintAxis axis, CGFloat spacing) {
  UIStackView *group = [UIStackView new];
  group.axis = axis;
  group.alignment = UIStackViewAlignmentCenter;
  group.spacing = spacing;
  return group;
}

static UIView *pudu_make_column(void) { return pudu_make_group(UILayoutConstraintAxisVertical, 16); }
static UIView *pudu_make_row(void) { return pudu_make_group(UILayoutConstraintAxisHorizontal, 12); }

static UIView *pudu_make_field(void) {
  UITextField *field = [UITextField new];
  field.borderStyle = UITextBorderStyleRoundedRect;
  [field.widthAnchor constraintGreaterThanOrEqualToConstant:220].active = YES;
  [field addTarget:pudu_target action:@selector(focused:) forControlEvents:UIControlEventEditingDidBegin];
  [field addTarget:pudu_target action:@selector(edited:) forControlEvents:UIControlEventEditingChanged];
  return field;
}

static UIView *pudu_make_list(void) {
  return pudu_list_make(^(NSInteger tag, uint32_t visible) { pudu_queue(PUDU_UI_REACHED, tag, nil, visible); });
}

static UIView *pudu_make_toggle(void) {
  PuduToggle *toggle = [PuduToggle new];
  toggle.axis = UILayoutConstraintAxisHorizontal;
  toggle.spacing = 8;
  toggle.title = [UILabel new];
  toggle.control = [UISwitch new];
  [toggle.control addTarget:pudu_target action:@selector(switched:) forControlEvents:UIControlEventValueChanged];
  [toggle addArrangedSubview:toggle.title];
  [toggle addArrangedSubview:toggle.control];
  return toggle;
}

/* Setters a kind accepts; a kind without one refuses that instruction. */
static void pudu_label_text(UIView *view, NSString *text) { ((UILabel *)view).text = text; }
static void pudu_button_text(UIView *view, NSString *text) { [(UIButton *)view setTitle:text forState:UIControlStateNormal]; }

/* A field already showing the text is left alone, so typing keeps its place. */
static void pudu_field_text(UIView *view, NSString *text) {
  UITextField *field = (UITextField *)view;
  if (![field.text isEqualToString:text]) field.text = text;
}

static void pudu_field_hint(UIView *view, NSString *hint) { ((UITextField *)view).placeholder = hint; }
static void pudu_toggle_text(UIView *view, NSString *text) { ((PuduToggle *)view).title.text = text; }
static void pudu_toggle_state(UIView *view, uint32_t state) { ((PuduToggle *)view).control.on = state != 0; }
static UIView *pudu_toggle_control(UIView *view) { return ((PuduToggle *)view).control; }
static void pudu_toggle_paint(UIView *view, UIColor *color) { pudu_label_paint(((PuduToggle *)view).title, color); }
static void pudu_toggle_style(UIView *view, UIFont *font) { pudu_label_style(((PuduToggle *)view).title, font); }
static UIView *pudu_itself(UIView *view) { return view; }
static UIStackView *pudu_direct_stack(UIView *view) { return (UIStackView *)view; }
/* What a self-test does to a kind, and what a kind reports afterward. */
static void pudu_field_fill(UIView *view, NSString *text) {
  ((UITextField *)view).text = text;
  [(UITextField *)view sendActionsForControlEvents:UIControlEventEditingChanged];
}

static void pudu_toggle_fill(UIView *view, NSString *text) {
  (void)text;
  ((PuduToggle *)view).control.on = YES;
  [((PuduToggle *)view).control sendActionsForControlEvents:UIControlEventValueChanged];
}

static void pudu_button_press(UIView *view) { [(UIButton *)view sendActionsForControlEvents:UIControlEventTouchUpInside]; }
static NSString *pudu_label_shown(UIView *view) { return ((UILabel *)view).text; }

#endif
