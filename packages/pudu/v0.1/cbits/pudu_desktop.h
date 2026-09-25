#ifndef PUDU_DESKTOP_H
#define PUDU_DESKTOP_H

#include <stddef.h>
#include <stdint.h>

void *pudu_desktop_open(
    const uint8_t *title,
    size_t title_length,
    int32_t width,
    int32_t height,
    int32_t resizable);

int32_t pudu_desktop_present(
    void *handle,
    int32_t width,
    int32_t height,
    const uint8_t *rgba,
    size_t rgba_length);

int32_t pudu_desktop_pump(void *handle, int32_t milliseconds);
int32_t pudu_desktop_close(void *handle);

/* Input queued by pump, as newline-terminated tab-separated records:
   press x y, key name, text utf8, scroll x y delta, chord name, resize w h,
   and pointer phases down|move|up x y milliseconds.
   Answers the queued byte count; copies and clears the queue only when it
   fits in capacity. Negative answers are the same statuses as pump. */
int64_t pudu_desktop_inputs(void *handle, uint8_t *buffer, size_t capacity);

/* The general pasteboard's plain text: answers its byte length and copies it
   only when it fits in capacity; -5 when it holds no text. */
int64_t pudu_desktop_clipboard_read(uint8_t *buffer, size_t capacity);

/* Replaces the general pasteboard's contents with UTF-8 text. */
int32_t pudu_desktop_clipboard_write(const uint8_t *text, size_t length);

/* Replaces the window's accessibility tree with newline-terminated records:
   node parent role focused x y width height name, tab-separated, frames in
   top-left content pixels, each parent -1 or an earlier record's node.
   -3 when a record cannot be read, leaving the previous tree in place. */
int32_t pudu_desktop_accessibility(void *handle, const uint8_t *records, size_t length);

/* What AppKit reports for the window's accessibility tree, as records of the
   same form in preorder, numbered from zero, with the platform's roles.
   Answers the byte count and copies only when it fits in capacity. */
int64_t pudu_desktop_accessibility_report(void *handle, uint8_t *buffer, size_t capacity);

/* Replaces the application's menu bar with newline-terminated records, depth
   first: menu depth title; command depth name chord title; separator depth.
   Choosing a command queues a menu name input record. -3 when a record cannot
   be read, leaving the previous bar in place. */
int32_t pudu_desktop_menu(void *handle, const uint8_t *records, size_t length);

/* The installed bar as records of the same form, without the application
   menu. Answers the byte count and copies only when it fits in capacity. */
int64_t pudu_desktop_menu_report(void *handle, uint8_t *buffer, size_t capacity);

#endif
