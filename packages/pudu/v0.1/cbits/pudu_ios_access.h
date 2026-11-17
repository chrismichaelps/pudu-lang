#ifndef PUDU_IOS_ACCESS_H
#define PUDU_IOS_ACCESS_H

/* Accessibility beyond names, and context menus. TRAITS bits follow
   Std.Mobile.Access in the platform's own order; the two traits introduced
   in iOS 17 apply only on iOS 17 or later. A context menu reports PICKED
   with its tag and the chosen item's index. */
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#include <stdint.h>
#include <stdio.h>
#include "pudu_ios_events.h"

enum { PUDU_TRAITS_BEFORE_17 = 17, PUDU_TRAITS = 19 };

/* The traits of a TRAITS mask on this system. */
static UIAccessibilityTraits pudu_traits_of(uint32_t mask) {
  const UIAccessibilityTraits traits[PUDU_TRAITS_BEFORE_17] = {
    UIAccessibilityTraitButton, UIAccessibilityTraitLink, UIAccessibilityTraitHeader, UIAccessibilityTraitSearchField,
    UIAccessibilityTraitImage, UIAccessibilityTraitSelected, UIAccessibilityTraitPlaysSound,
    UIAccessibilityTraitKeyboardKey, UIAccessibilityTraitStaticText, UIAccessibilityTraitSummaryElement,
    UIAccessibilityTraitNotEnabled, UIAccessibilityTraitUpdatesFrequently, UIAccessibilityTraitStartsMediaSession,
    UIAccessibilityTraitAdjustable, UIAccessibilityTraitAllowsDirectInteraction, UIAccessibilityTraitCausesPageTurn,
    UIAccessibilityTraitTabBar,
  };
  UIAccessibilityTraits found = UIAccessibilityTraitNone;
  for (uint32_t bit = 0; bit < PUDU_TRAITS_BEFORE_17; bit++) {
    if (mask & (1u << bit)) found |= traits[bit];
  }
  if (@available(iOS 17.0, *)) {
    if (mask & (1u << 17)) found |= UIAccessibilityTraitToggleButton;
    if (mask & (1u << 18)) found |= UIAccessibilityTraitSupportsZoom;
  }
  return found;
}

/* A control's context menu: its tag, and each choice's role and label. */
@interface PuduMenu : NSObject <UIContextMenuInteractionDelegate>
@property (nonatomic) NSInteger tag;
@property (strong, nonatomic) NSArray<NSArray *> *choices;
@end
@implementation PuduMenu
- (UIContextMenuConfiguration *)contextMenuInteraction:(UIContextMenuInteraction *)interaction
                        configurationForMenuAtLocation:(CGPoint)location {
  (void)interaction;
  (void)location;
  return [UIContextMenuConfiguration configurationWithIdentifier:nil previewProvider:nil
                                                  actionProvider:^UIMenu *(NSArray<UIMenuElement *> *suggested) {
    (void)suggested;
    return [UIMenu menuWithTitle:@"" children:[self actions]];
  }];
}
- (NSArray<UIAction *> *)actions {
  NSMutableArray<UIAction *> *actions = [NSMutableArray new];
  for (NSUInteger index = 0; index < self.choices.count; index++) {
    UIAction *action = [UIAction actionWithTitle:self.choices[index][1] image:nil identifier:nil
                                         handler:^(UIAction *taken) { (void)taken; [self pick:index]; }];
    if ([self.choices[index][0] unsignedIntValue] == 2) action.attributes = UIMenuElementAttributesDestructive;
    [actions addObject:action];
  }
  return actions;
}
- (void)pick:(NSUInteger)index { pudu_queue(PUDU_UI_PICKED, self.tag, nil, (uint32_t)index); }
@end

static const char pudu_menu_key = 0;

/* Replaces a control's context menu. */
static void pudu_menu_attach(UIView *control, NSInteger tag, NSArray<NSArray *> *choices) {
  PuduMenu *menu = objc_getAssociatedObject(control, &pudu_menu_key);
  if (menu == nil) {
    menu = [PuduMenu new];
    objc_setAssociatedObject(control, &pudu_menu_key, menu, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [control addInteraction:[[UIContextMenuInteraction alloc] initWithDelegate:menu]];
    control.userInteractionEnabled = YES;
  }
  menu.tag = tag;
  menu.choices = choices;
}

/* The menu a control carries, for a self-test to pick from. */
static PuduMenu *pudu_menu_of(UIView *control) { return objc_getAssociatedObject(control, &pudu_menu_key); }

#endif
