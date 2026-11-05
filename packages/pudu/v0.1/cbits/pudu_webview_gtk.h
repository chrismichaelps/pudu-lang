#ifndef PUDU_WEBVIEW_GTK_H
#define PUDU_WEBVIEW_GTK_H

#include "pudu_webview.h"
#include "pudu_webview_records.h"

#include <gtk/gtk.h>
#include <webkit2/webkit2.h>

typedef struct {
  int64_t id;
  GtkWidget *window;
  GtkWidget *fixed;
  int width;
  int height;
} PuduWindow;

/* One view: its configuration until realized, then its WebView. */
typedef struct {
  int64_t id;
  int64_t window;
  int x, y, width, height;
  gboolean fill;
  GtkWidget *web;
  WebKitUserContentManager *content;
  GPtrArray *scripts;
  GPtrArray *allowed;
  GPtrArray *rules;
  char *url;
  char *html;
  char *agent;
  char *store;
  gboolean ephemeral;
  gboolean devtools;
  gboolean transparent;
  double zoom;
  guint rules_outstanding;
  gboolean rules_failed;
} PuduView;

/* One request WebKit is waiting on. */
typedef struct {
  WebKitURISchemeRequest *request;
  GBytes *body;
} PuduPending;

extern GHashTable *pudu_views;
extern GHashTable *pudu_pending;
extern int64_t pudu_next_request;

int32_t pudu_refuse(int32_t status, const char *reason);
/* Queues one event of text fields and wakes the main context. */
void pudu_event(const char *const *fields, int count);
char *pudu_number(int64_t value);
int64_t *pudu_key(int64_t value);
PuduWindow *pudu_window_named(int64_t id);
/* Applies one view record (fields[0] is "view"). */
int32_t pudu_view_command(pudu_field *fields, int count);

#endif
