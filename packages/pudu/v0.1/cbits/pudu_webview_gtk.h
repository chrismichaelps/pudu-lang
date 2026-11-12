#ifndef PUDU_WEBVIEW_GTK_H
#define PUDU_WEBVIEW_GTK_H

#include "pudu_webview.h"
#include "pudu_webview_records.h"

#include <gtk/gtk.h>
#include <webkit2/webkit2.h>

typedef struct {
  int64_t id;
  GtkWidget *window;
  /* The window's column: an optional menu bar above the fixed container. */
  GtkWidget *box;
  GtkWidget *overlay;
  GtkWidget *titlebar;
  GtkWidget *overlaybar;
  GtkCssProvider *background_css;
  GtkWidget *menubar;
  GtkAccelGroup *accelerators;
  GtkWidget *fixed;
  int width;
  int height;
  int min_width, min_height, max_width, max_height;
  gboolean minimizable, maximizable;
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
  gboolean inspector_open, inspector_requested;
  gboolean transparent;
  gboolean file_drop, drop_inside;
  GHashTable *window_actions;
  char *native_key;
  GdkEvent *press;
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

int32_t pudu_webview_guard(void);
int32_t pudu_refuse(int32_t status, const char *reason);
/* Queues one event of text fields and wakes the main context. */
void pudu_event(const char *const *fields, int count);
char *pudu_number(int64_t value);
int64_t *pudu_key(int64_t value);
PuduWindow *pudu_window_named(int64_t id);
GHashTable *pudu_window_table(void);
/* Applies one view record (fields[0] is "view"). */
int32_t pudu_view_command(pudu_field *fields, int count);
/* Applies one native-component record (fields[0] is "app" or "surface"). */
int32_t pudu_native_command(pudu_field *fields, int count);
/* Gives a newly opened window the application's menu bar. */
void pudu_native_window_opened(PuduWindow *owner);
GtkWidget *pudu_fixed_new(void);
void pudu_window_hooks(PuduWindow *owner);
void pudu_window_report(PuduWindow *owner);
void pudu_window_title(PuduWindow *owner);
void pudu_window_geometry(PuduWindow *owner);
int32_t pudu_window_extra(PuduWindow *owner, pudu_field *fields, int count);
WebKitWebContext *pudu_view_context(PuduView *view);
void pudu_scheme_request(WebKitURISchemeRequest *request, gpointer data);
void pudu_view_interaction(PuduView *view);
void pudu_view_closed(PuduView *view);
int32_t pudu_view_authority(PuduView *view, pudu_field *fields, int count);
int32_t pudu_view_extra(PuduView *view, pudu_field *fields, int count);

#endif
