#ifndef PUDU_IOS_LAYOUT_H
#define PUDU_IOS_LAYOUT_H

#import <UIKit/UIKit.h>

@interface PuduScroll : UIScrollView
@property (strong, nonatomic) UIStackView *content;
@property (weak, nonatomic) UITextField *focusedField;
- (void)revealField;
@end

@implementation PuduScroll {
  CGSize previousViewport;
}
- (void)revealField {
  UITextField *field = self.focusedField;
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

static void pudu_focus_field(UITextField *sender) {
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

#endif
