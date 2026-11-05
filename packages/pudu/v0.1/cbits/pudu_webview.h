#ifndef PUDU_WEBVIEW_H
#define PUDU_WEBVIEW_H

#include <stddef.h>
#include <stdint.h>

/* Statuses shared by every entry point. */
#define PUDU_WEBVIEW_DONE 0
#define PUDU_WEBVIEW_QUEUED 1
#define PUDU_WEBVIEW_INVALID (-1)
#define PUDU_WEBVIEW_NOT_MAIN (-2)
#define PUDU_WEBVIEW_MALFORMED (-3)
#define PUDU_WEBVIEW_PLATFORM (-4)
#define PUDU_WEBVIEW_UNKNOWN (-5)
#define PUDU_WEBVIEW_GONE (-6)
#define PUDU_WEBVIEW_UNSUPPORTED (-7)

/* Applies newline-terminated command records in order, stopping at the
   first that fails; pudu_webview_failure then names it. */
int32_t pudu_webview_send(const uint8_t *records, size_t length);

/* Runs the platform loop for at most milliseconds, returning early with
   PUDU_WEBVIEW_QUEUED once an event is queued. */
int32_t pudu_webview_pump(int32_t milliseconds);

/* Queued event records: answers their byte count, and copies and clears
   them only when they fit in capacity. */
int64_t pudu_webview_events(uint8_t *buffer, size_t capacity);

/* The body of pending request `request`, measured or copied the same way. */
int64_t pudu_webview_body(int64_t request, uint8_t *buffer, size_t capacity);

/* Finishes pending request `request`. `head` holds "Name: value" lines. */
int32_t pudu_webview_respond(
    int64_t request,
    int32_t status,
    const uint8_t *head,
    size_t head_length,
    const uint8_t *body,
    size_t body_length);

/* Why the last refused command was refused, measured or copied the same way. */
int64_t pudu_webview_failure(uint8_t *buffer, size_t capacity);

#endif
