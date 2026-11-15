#ifndef PUDU_IOS_THEME_H
#define PUDU_IOS_THEME_H

/* Semantic color roles, the appearance override and text styles of the iOS
   host. A fixed tone becomes a dynamic platform color, so an appearance
   change is resolved by UIKit at draw time and never reaches Pudu. Text
   styles adjust to the content size category the same way. */
#import <UIKit/UIKit.h>
#include <math.h>
#include <stdint.h>
#include <stdio.h>

enum { PUDU_ROLE_SURFACE = 0, PUDU_ROLE_INK = 1, PUDU_ROLE_ACCENT = 2, PUDU_ROLE_ON_ACCENT = 3, PUDU_ROLE_MUTED = 4,
       PUDU_ROLE_DANGER = 5, PUDU_ROLE_SEPARATOR = 6, PUDU_ROLES = 7 };
enum { PUDU_TONE_PLATFORM = 0, PUDU_TONE_FIXED = 1 };
enum { PUDU_STYLES = 9 };
/* A node without an explicit COLOR. */
static const uint32_t PUDU_ROLE_DEFAULT = UINT32_MAX;

static UIColor *pudu_roles[PUDU_ROLES];
static UIColor *pudu_platform_roles[PUDU_ROLES];

/* Every role back to the platform's own semantic color. */
static void pudu_theme_reset(void) {
  if (pudu_platform_roles[0] == nil) {
    UIColor *platform[PUDU_ROLES] = {
      [PUDU_ROLE_SURFACE] = UIColor.systemBackgroundColor, [PUDU_ROLE_INK] = UIColor.labelColor,
      [PUDU_ROLE_ACCENT] = UIColor.systemBlueColor, [PUDU_ROLE_ON_ACCENT] = UIColor.whiteColor,
      [PUDU_ROLE_MUTED] = UIColor.secondaryLabelColor, [PUDU_ROLE_DANGER] = UIColor.systemRedColor,
      [PUDU_ROLE_SEPARATOR] = UIColor.separatorColor,
    };
    for (uint32_t role = 0; role < PUDU_ROLES; role++) pudu_platform_roles[role] = platform[role];
  }
  for (uint32_t role = 0; role < PUDU_ROLES; role++) pudu_roles[role] = pudu_platform_roles[role];
}

/* A packed color: red in the low byte, alpha in the high byte. */
static UIColor *pudu_packed_color(uint32_t packed) {
  return [UIColor colorWithRed:(packed & 0xff) / 255.0
                         green:(packed >> 8 & 0xff) / 255.0
                          blue:(packed >> 16 & 0xff) / 255.0
                         alpha:(packed >> 24 & 0xff) / 255.0];
}

static UIColor *pudu_fixed_tone(uint32_t light, uint32_t dark) {
  UIColor *lit = pudu_packed_color(light);
  UIColor *dim = pudu_packed_color(dark);
  return [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *traits) {
    return traits.userInterfaceStyle == UIUserInterfaceStyleDark ? dim : lit;
  }];
}

/* The platform text style of each STYLE code; zero is never written. */
static UIFontTextStyle pudu_text_style(uint32_t code) {
  static UIFontTextStyle styles[PUDU_STYLES];
  if (styles[1] == nil) {
    styles[1] = UIFontTextStyleLargeTitle;
    styles[2] = UIFontTextStyleTitle1;
    styles[3] = UIFontTextStyleHeadline;
    styles[4] = UIFontTextStyleBody;
    styles[5] = UIFontTextStyleCallout;
    styles[6] = UIFontTextStyleSubheadline;
    styles[7] = UIFontTextStyleFootnote;
    styles[8] = UIFontTextStyleCaption1;
  }
  return code > 0 && code < PUDU_STYLES ? styles[code] : nil;
}

/* The window override of each APPEARANCE code. */
enum { PUDU_APPEARANCES = 3 };
static const UIUserInterfaceStyle pudu_interface_styles[PUDU_APPEARANCES] = {
  UIUserInterfaceStyleUnspecified, UIUserInterfaceStyleLight, UIUserInterfaceStyleDark,
};

/* Paint and style hooks, one per kind that shows text. */
static void pudu_label_paint(UIView *view, UIColor *color) { ((UILabel *)view).textColor = color; }

static void pudu_label_style(UIView *view, UIFont *font) {
  ((UILabel *)view).font = font;
  ((UILabel *)view).adjustsFontForContentSizeCategory = YES;
}

static void pudu_button_paint(UIView *view, UIColor *color) { [(UIButton *)view setTitleColor:color forState:UIControlStateNormal]; }

static void pudu_button_style(UIView *view, UIFont *font) {
  ((UIButton *)view).titleLabel.font = font;
  ((UIButton *)view).titleLabel.adjustsFontForContentSizeCategory = YES;
}

static void pudu_field_paint(UIView *view, UIColor *color) { ((UITextField *)view).textColor = color; }

static void pudu_field_style(UIView *view, UIFont *font) {
  ((UITextField *)view).font = font;
  ((UITextField *)view).adjustsFontForContentSizeCategory = YES;
}

/* A color as #RRGGBBAA once resolved for one appearance. */
static NSString *pudu_hex(UIColor *color, UIUserInterfaceStyle style) {
  CGFloat red = 0, green = 0, blue = 0, alpha = 0;
  UITraitCollection *traits = [UITraitCollection traitCollectionWithUserInterfaceStyle:style];
  [[color resolvedColorWithTraitCollection:traits] getRed:&red green:&green blue:&blue alpha:&alpha];
  return [NSString stringWithFormat:@"#%02X%02X%02X%02X", (int)lround(red * 255), (int)lround(green * 255),
                                    (int)lround(blue * 255), (int)lround(alpha * 255)];
}

static CGFloat pudu_point_size(UIFontTextStyle style, UIContentSizeCategory category) {
  UITraitCollection *traits = [UITraitCollection traitCollectionWithPreferredContentSizeCategory:category];
  return [UIFont preferredFontForTextStyle:style compatibleWithTraitCollection:traits].pointSize;
}

/* Self-test: the first label's text color under light and dark traits, the
   window's appearance override, and whether its text style grows with the
   content size category. `done` asks the program to stop. */
static void pudu_test_theme(UIView *surface, NSArray *nodes, void (^done)(void)) {
  UILabel *label = nil;
  for (NSObject *node in nodes) {
    if (label == nil && [node isKindOfClass:UILabel.class]) label = (UILabel *)node;
  }
  if (label != nil) {
    UIFontTextStyle style = label.font.fontDescriptor.fontAttributes[UIFontDescriptorTextStyleAttribute];
    printf("PUDU_THEME ink light %s dark %s\n", pudu_hex(label.textColor, UIUserInterfaceStyleLight).UTF8String,
           pudu_hex(label.textColor, UIUserInterfaceStyleDark).UTF8String);
    if (surface.window.overrideUserInterfaceStyle == UIUserInterfaceStyleDark) puts("PUDU_THEME appearance dark");
    if (style != nil && pudu_point_size(style, UIContentSizeCategoryAccessibilityExtraLarge) >
                            pudu_point_size(style, UIContentSizeCategoryLarge)) {
      puts("PUDU_THEME type grows");
    }
  }
  fflush(stdout);
  done();
}

#endif
