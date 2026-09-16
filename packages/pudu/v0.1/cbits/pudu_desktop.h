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

#endif
