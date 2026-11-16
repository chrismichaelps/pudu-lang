#ifndef PUDU_ANDROID_THEME_H
#define PUDU_ANDROID_THEME_H

/* Semantic color roles, the appearance override and text styles of the
   Android host. Each role holds a light and a dark color; which one shows is
   decided by the appearance the program asked for, or by the system's night
   mode when it asked for none, and every painted node is repainted when that
   changes. Text sizes are scaled pixels, so the system font scale applies. */
#include <jni.h>
#include <stdint.h>
#include "pudu_android_jni.h"

enum { PUDU_ROLE_SURFACE = 0, PUDU_ROLE_INK = 1, PUDU_ROLE_ACCENT = 2, PUDU_ROLE_ON_ACCENT = 3, PUDU_ROLE_MUTED = 4,
       PUDU_ROLE_DANGER = 5, PUDU_ROLE_SEPARATOR = 6, PUDU_ROLES = 7 };
enum { PUDU_TONE_PLATFORM = 0, PUDU_TONE_FIXED = 1 };
enum { PUDU_STYLES = 9, PUDU_APPEARANCES = 3 };
/* A node without an explicit COLOR. */
static const uint32_t PUDU_ROLE_DEFAULT = UINT32_MAX;

/* The platform's own tones, packed as the stream packs them: red in the low
   byte, alpha in the high byte. */
static const uint32_t pudu_platform_light[PUDU_ROLES] = {
  0xFFFFFFFFu, 0xFF1F1B1Cu, 0xFFA45067u, 0xFFFFFFFFu, 0xFF4F4549u, 0xFF1E26B3u, 0xFFD0C4CAu,
};
static const uint32_t pudu_platform_dark[PUDU_ROLES] = {
  0xFF121212u, 0xFFE5E1E6u, 0xFFFFBCD0u, 0xFF721E38u, 0xFFD0C4CAu, 0xFFB5B8F2u, 0xFF4F4549u,
};

static uint32_t pudu_role_light[PUDU_ROLES], pudu_role_dark[PUDU_ROLES];
/* The APPEARANCE code: 0 follows the system, 1 light, 2 dark. */
static uint32_t pudu_appearance;
/* Whether the system is in night mode, read on the main thread. */
static int pudu_system_night;

static void pudu_theme_reset(void) {
  for (uint32_t role = 0; role < PUDU_ROLES; role++) {
    pudu_role_light[role] = pudu_platform_light[role];
    pudu_role_dark[role] = pudu_platform_dark[role];
  }
  pudu_appearance = 0;
}

static int pudu_night(void) { return pudu_appearance == 2 || (pudu_appearance == 0 && pudu_system_night); }

/* A packed color as the framework's ARGB integer. */
static jint pudu_argb(uint32_t packed) {
  uint32_t red = packed & 0xff, green = packed >> 8 & 0xff, blue = packed >> 16 & 0xff, alpha = packed >> 24 & 0xff;
  return (jint)(alpha << 24 | red << 16 | green << 8 | blue);
}

/* A role's color for the appearance in effect. */
static jint pudu_role_color(uint32_t role) {
  return pudu_argb(pudu_night() ? pudu_role_dark[role] : pudu_role_light[role]);
}

/* The size in scaled pixels and the weight of each STYLE code; zero is
   never written. The sizes follow the iOS text styles' default sizes. */
static const float pudu_style_sizes[PUDU_STYLES] = {0, 34, 28, 17, 17, 16, 15, 13, 12};
static const int pudu_style_bold[PUDU_STYLES] = {0, 1, 1, 1, 0, 0, 0, 0, 0};

static int pudu_style_known(uint32_t code) { return code > 0 && code < PUDU_STYLES; }

/* The text of a TextView, or of the TextView a compound view shows. */
static void pudu_text_paint(JNIEnv *env, jobject text, jint color) { pudu_call(env, text, "setTextColor", "(I)V", color); }

static void pudu_text_style(JNIEnv *env, jobject text, uint32_t code) {
  pudu_call(env, text, "setTextSize", "(IF)V", (jint)2, (jfloat)pudu_style_sizes[code]);
  pudu_bridge(env, "bold", "(Landroid/widget/TextView;Z)V", text, (jboolean)pudu_style_bold[code]);
}

#endif
