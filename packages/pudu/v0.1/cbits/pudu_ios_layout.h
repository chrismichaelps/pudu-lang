#ifndef PUDU_IOS_LAYOUT_H
#define PUDU_IOS_LAYOUT_H

#import <UIKit/UIKit.h>

@interface PuduScroll : UIScrollView
@property (strong, nonatomic) UIStackView *content;
@property (weak, nonatomic) UIView *focusedField;
- (void)revealField;
@end

@implementation PuduScroll {
  CGSize previousViewport;
}
- (void)revealField {
  UIView *field = self.focusedField;
  if (field.isFirstResponder && [field isDescendantOfView:self]) {
    [self scrollRectToVisible:[field convertRect:field.bounds toView:self] animated:NO];
  }
}
- (void)layoutSubviews {
  [super layoutSubviews];
  if (!CGSizeEqualToSize(previousViewport, self.bounds.size)) {
    previousViewport = self.bounds.size;
    [self revealField];
  }
}
@end

/* A field or text area taking focus is kept visible inside its scroll view. */
static void pudu_focus_field(UIView *sender) {
  for (UIView *parent = sender.superview; parent != nil; parent = parent.superview) {
    if ([parent isKindOfClass:PuduScroll.class]) {
      PuduScroll *scroll = (PuduScroll *)parent;
      scroll.focusedField = sender;
      [scroll revealField];
      return;
    }
  }
}

static UIView *pudu_make_scroll(void) {
  PuduScroll *scroll = [PuduScroll new];
  scroll.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
  scroll.keyboardDismissMode = UIScrollViewKeyboardDismissModeOnDrag;
  UIStackView *content = [UIStackView new];
  content.axis = UILayoutConstraintAxisVertical;
  content.alignment = UIStackViewAlignmentCenter;
  content.translatesAutoresizingMaskIntoConstraints = NO;
  scroll.content = content;
  [scroll addSubview:content];
  UILayoutGuide *area = scroll.contentLayoutGuide;
  [NSLayoutConstraint activateConstraints:@[
    [content.leadingAnchor constraintEqualToAnchor:area.leadingAnchor],
    [content.trailingAnchor constraintEqualToAnchor:area.trailingAnchor],
    [content.topAnchor constraintEqualToAnchor:area.topAnchor],
    [content.bottomAnchor constraintEqualToAnchor:area.bottomAnchor],
    [content.widthAnchor constraintEqualToAnchor:scroll.frameLayoutGuide.widthAnchor] ]];
  return scroll;
}

static UIStackView *pudu_scroll_stack(UIView *view) { return ((PuduScroll *)view).content; }

static UILayoutGuide *pudu_available_area(UIView *surface) {
  UILayoutGuide *area = [UILayoutGuide new];
  [surface addLayoutGuide:area];
  UILayoutGuide *safe = surface.safeAreaLayoutGuide;
  // Prefer the full safe area, subject to the keyboard's upper edge.
  NSLayoutConstraint *fullHeight = [area.bottomAnchor constraintEqualToAnchor:safe.bottomAnchor];
  fullHeight.priority = UILayoutPriorityRequired - 1;
  [NSLayoutConstraint activateConstraints:@[
    [area.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor],
    [area.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor],
    [area.topAnchor constraintEqualToAnchor:safe.topAnchor],
    [area.bottomAnchor constraintLessThanOrEqualToAnchor:safe.bottomAnchor],
    [area.bottomAnchor constraintLessThanOrEqualToAnchor:surface.keyboardLayoutGuide.topAnchor],
    fullHeight ]];
  return area;
}

static void pudu_place_root(UIView *root, UILayoutGuide *area, BOOL fillsArea) {
  if (fillsArea) {
    [NSLayoutConstraint activateConstraints:@[
      [root.leadingAnchor constraintEqualToAnchor:area.leadingAnchor],
      [root.trailingAnchor constraintEqualToAnchor:area.trailingAnchor],
      [root.topAnchor constraintEqualToAnchor:area.topAnchor],
      [root.bottomAnchor constraintEqualToAnchor:area.bottomAnchor] ]];
  } else {
    [NSLayoutConstraint activateConstraints:@[
      [root.centerXAnchor constraintEqualToAnchor:area.centerXAnchor],
      [root.centerYAnchor constraintEqualToAnchor:area.centerYAnchor],
      [root.leadingAnchor constraintGreaterThanOrEqualToAnchor:area.leadingAnchor],
      [root.trailingAnchor constraintLessThanOrEqualToAnchor:area.trailingAnchor],
      [root.topAnchor constraintGreaterThanOrEqualToAnchor:area.topAnchor],
      [root.bottomAnchor constraintLessThanOrEqualToAnchor:area.bottomAnchor] ]];
  }
}

/* Self-test: the viewport fills the safe area and scrolls, a focused field
   stays visible above the docked keyboard, and dismissal restores the
   original viewport. `done` asks the program to stop. */
static void pudu_test_keyboard(UIView *pudu_surface, UIView *root, NSArray *pudu_nodes, void (^done)(void)) {
  [pudu_surface layoutIfNeeded];
  UITextField *field = nil;
  for (NSObject *node in pudu_nodes) {
    if ([node isKindOfClass:UITextField.class]) field = (UITextField *)node;
  }
  if (![root isKindOfClass:PuduScroll.class] || field == nil) {
    done();
    return;
  }

  PuduScroll *scroll = (PuduScroll *)root;
  CGRect original = scroll.frame;
  CGRect safe = pudu_surface.safeAreaLayoutGuide.layoutFrame;
  if (CGRectContainsRect(CGRectInset(safe, -1, -1), original) &&
      scroll.contentSize.height > scroll.bounds.size.height &&
      !CGRectIntersectsRect(scroll.bounds, [field convertRect:field.bounds toView:scroll])) {
    puts("PUDU_VIEWPORT safe and scrollable");
  }

  [field becomeFirstResponder];
  CFTimeInterval deadline = CACurrentMediaTime() + 10;
  __block BOOL dismissed = NO;
  [NSTimer scheduledTimerWithTimeInterval:0.05 repeats:YES block:^(NSTimer *timer) {
    [pudu_surface layoutIfNeeded];
    CGFloat bottom = CGRectGetMaxY(scroll.frame);
    CGFloat keyboard = CGRectGetMinY(pudu_surface.keyboardLayoutGuide.layoutFrame);
    if (!dismissed && keyboard < CGRectGetMaxY(original) - 1 && bottom <= keyboard + 1 &&
        field.isFirstResponder &&
        CGRectContainsRect(CGRectInset(scroll.bounds, -1, -1), [field convertRect:field.bounds toView:scroll])) {
      puts("PUDU_KEYBOARD visible field");
      dismissed = [field resignFirstResponder];
    } else if (dismissed && fabs(bottom - CGRectGetMaxY(original)) <= 1) {
      puts("PUDU_KEYBOARD restored");
      [timer invalidate];
      done();
    } else if (CACurrentMediaTime() >= deadline) {
      CGRect frame = [field convertRect:field.bounds toView:scroll];
      fprintf(stderr, "pudu: keyboard test timed out (initial=%g viewport=%g keyboard=%g offset=%g field=%g..%g focus=%d dismissed=%d)\n",
              CGRectGetMaxY(original), bottom, keyboard, scroll.contentOffset.y,
              CGRectGetMinY(frame), CGRectGetMaxY(frame), field.isFirstResponder, dismissed);
      [timer invalidate];
      done();
    }
  }];
}

#endif
