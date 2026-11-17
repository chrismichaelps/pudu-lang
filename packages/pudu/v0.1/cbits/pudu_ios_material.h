#ifndef PUDU_IOS_MATERIAL_H
#define PUDU_IOS_MATERIAL_H

/* System materials behind content: the first platform capability adopted
   through both gates. The glass realization compiles only when the selected
   SDK declares iOS 26, and runs only on iOS 26 or later; every other case
   takes the matching blur material, so appearance degrades and function does
   not. */
#import <UIKit/UIKit.h>
#include <stdint.h>
#include <stdio.h>

enum { PUDU_MATERIALS = 4 };

#if defined(__IPHONE_26_0) && __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_26_0
#define PUDU_SDK_HAS_GLASS 1
#else
#define PUDU_SDK_HAS_GLASS 0
#endif

/* A material surface: the effect view, and the stack its children join. */
@interface PuduMaterial : UIVisualEffectView
@property (strong, nonatomic) UIStackView *content;
@property (nonatomic) BOOL glass;
@end
@implementation PuduMaterial
@end

/* The blur of each MATERIAL code; zero is never written. */
static const UIBlurEffectStyle pudu_blur_styles[PUDU_MATERIALS] = {
  UIBlurEffectStyleSystemMaterial, UIBlurEffectStyleSystemThinMaterial, UIBlurEffectStyleSystemMaterial,
  UIBlurEffectStyleSystemThickMaterial,
};

static UIView *pudu_material_make(void) {
  PuduMaterial *material = [PuduMaterial new];
  UIStackView *content = [UIStackView new];
  content.axis = UILayoutConstraintAxisVertical;
  content.alignment = UIStackViewAlignmentCenter;
  content.spacing = 12;
  content.layoutMargins = UIEdgeInsetsMake(16, 16, 16, 16);
  content.layoutMarginsRelativeArrangement = YES;
  content.translatesAutoresizingMaskIntoConstraints = NO;
  material.content = content;
  material.layer.cornerRadius = 20;
  material.layer.cornerCurve = kCACornerCurveContinuous;
  material.clipsToBounds = YES;
  [material.contentView addSubview:content];
  [NSLayoutConstraint activateConstraints:@[
    [content.topAnchor constraintEqualToAnchor:material.contentView.topAnchor],
    [content.bottomAnchor constraintEqualToAnchor:material.contentView.bottomAnchor],
    [content.leadingAnchor constraintEqualToAnchor:material.contentView.leadingAnchor],
    [content.trailingAnchor constraintEqualToAnchor:material.contentView.trailingAnchor],
  ]];
  return material;
}

static UIStackView *pudu_material_stack(UIView *view) { return ((PuduMaterial *)view).content; }

/* Sets the effect for a MATERIAL code; answers whether the code is known. */
static BOOL pudu_material_set(UIView *view, uint32_t code) {
  PuduMaterial *material = (PuduMaterial *)view;
  if (code == 0 || code >= PUDU_MATERIALS) return NO;
#if PUDU_SDK_HAS_GLASS
  if (@available(iOS 26.0, *)) {
    const UIGlassEffectStyle styles[PUDU_MATERIALS] = {
      UIGlassEffectStyleRegular, UIGlassEffectStyleClear, UIGlassEffectStyleRegular, UIGlassEffectStyleRegular,
    };
    material.effect = [UIGlassEffect effectWithStyle:styles[code]];
    material.glass = YES;
    return YES;
  }
#endif
  material.effect = [UIBlurEffect effectWithStyle:pudu_blur_styles[code]];
  material.glass = NO;
  return YES;
}

/* Self-test: which realization the first material node used. */
static void pudu_test_material(NSArray *nodes, void (^done)(void)) {
  for (NSObject *node in nodes) {
    if ([node isKindOfClass:PuduMaterial.class]) {
      printf("PUDU_MATERIAL %s\n", ((PuduMaterial *)node).glass ? "glass" : "blur");
      break;
    }
  }
  fflush(stdout);
  done();
}

#endif
