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
   press x y, key name, text utf8, scroll x y delta, chord name, resize w h.
   Answers the queued byte count; copies and clears the queue only when it
   fits in capacity. Negative answers are the same statuses as pump. */
int64_t pudu_desktop_inputs(void *handle, uint8_t *buffer, size_t capacity);

#endif
