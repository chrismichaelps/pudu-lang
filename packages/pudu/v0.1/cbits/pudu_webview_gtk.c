#include "pudu_webview_gtk.h"

#include <pthread.h>
#include <string.h>

/* Queued events past this many bytes are dropped until the program drains. */
#define PUDU_EVENT_LIMIT ((size_t)64 << 20)

static gboolean pudu_started;
static pthread_t pudu_thread;
static pudu_buffer pudu_events;
static char *pudu_failure;
static GHashTable *pudu_windows;
GHashTable *pudu_views;
GHashTable *pudu_pending;
int64_t pudu_next_request = 1;

int32_t pudu_refuse(int32_t status, const char *reason) {
  g_free(pudu_failure);
  pudu_failure = g_strdup(reason);
  return status;
}

void pudu_event(const char *const *fields, int count) {
  if (pudu_events.length > PUDU_EVENT_LIMIT) {
    return;
  }
  size_t saved = pudu_events.length;
  for (int i = 0; i < count; i++) {
    if (pudu_buffer_text(&pudu_events, fields[i] == NULL ? "" : fields[i]) != 0) {
      pudu_events.length = saved;
      return;
    }
  }
  if (pudu_buffer_end(&pudu_events) != 0) {
    pudu_events.length = saved;
    return;
  }
  g_main_context_wakeup(NULL);
}

char *pudu_number(int64_t value) {
  return g_strdup_printf("%lld", (long long)value);
}

static gboolean pudu_ready(void) {
  if (!pudu_started) {
    if (!gtk_init_check(NULL, NULL)) {
      return FALSE;
    }
    pudu_started = TRUE;
    pudu_thread = pthread_self();
    pudu_windows = g_hash_table_new(g_int64_hash, g_int64_equal);
    pudu_views = g_hash_table_new(g_int64_hash, g_int64_equal);
    pudu_pending = g_hash_table_new(g_int64_hash, g_int64_equal);
  }
  return pthread_equal(pudu_thread, pthread_self());
}

int64_t *pudu_key(int64_t value) {
  int64_t *key = g_new(int64_t, 1);
  *key = value;
  return key;
}

/* Window signals. */

static gboolean pudu_on_delete(GtkWidget *widget, GdkEvent *event, gpointer data) {
  (void)widget;
  (void)event;
  PuduWindow *owner = data;
  g_autofree char *id = pudu_number(owner->id);
  const char *fields[] = {"close-requested", id};
  pudu_event(fields, 2);
  return TRUE;
}

static gboolean pudu_on_configure(GtkWidget *widget, GdkEventConfigure *event, gpointer data) {
  (void)widget;
  PuduWindow *owner = data;
  g_autofree char *id = pudu_number(owner->id);
  g_autofree char *width = pudu_number(event->width);
  g_autofree char *height = pudu_number(event->height);
  g_autofree char *x = pudu_number(event->x);
  g_autofree char *y = pudu_number(event->y);
  const char *resized[] = {"resized", id, width, height};
  const char *moved[] = {"moved", id, x, y};
  pudu_event(resized, 4);
  pudu_event(moved, 4);
  GHashTableIter iter;
  gpointer key, value;
  g_hash_table_iter_init(&iter, pudu_views);
  while (g_hash_table_iter_next(&iter, &key, &value)) {
    PuduView *view = value;
    if (view->window == owner->id && view->fill && view->web != NULL) {
      gtk_widget_set_size_request(view->web, event->width, event->height);
    }
  }
  owner->width = event->width;
  owner->height = event->height;
  return FALSE;
}

static gboolean pudu_on_focus(GtkWidget *widget, GdkEventFocus *event, gpointer data) {
  (void)widget;
  PuduWindow *owner = data;
  g_autofree char *id = pudu_number(owner->id);
  const char *fields[] = {"focused", id, event->in ? "1" : "0"};
  pudu_event(fields, 3);
  return FALSE;
}

static int32_t pudu_window_command(pudu_field *fields, int count) {
  int64_t id = 0;
  if (count < 3 || pudu_field_int(fields[1], &id) != 0) {
    return pudu_refuse(PUDU_WEBVIEW_MALFORMED, "window record needs an id and a verb");
  }
  if (pudu_field_is(fields[2], "open")) {
    int64_t width = 0, height = 0, resizable = 0;
    if (count != 7 || pudu_field_int(fields[4], &width) != 0 || pudu_field_int(fields[5], &height) != 0 ||
        pudu_field_int(fields[6], &resizable) != 0 || width <= 0 || height <= 0) {
      return pudu_refuse(PUDU_WEBVIEW_MALFORMED, "window open needs a title, a positive size and a resizable flag");
    }
    if (g_hash_table_contains(pudu_windows, &id)) {
      return pudu_refuse(PUDU_WEBVIEW_INVALID, "window id is already open");
    }
    g_autofree char *title = pudu_field_copy(fields[3]);
    PuduWindow *owner = g_new0(PuduWindow, 1);
    owner->id = id;
    owner->window = gtk_window_new(GTK_WINDOW_TOPLEVEL);
    owner->fixed = gtk_fixed_new();
    gtk_window_set_title(GTK_WINDOW(owner->window), title == NULL ? "" : title);
    gtk_window_set_default_size(GTK_WINDOW(owner->window), (int)width, (int)height);
    owner->width = (int)width;
    owner->height = (int)height;
    gtk_window_set_resizable(GTK_WINDOW(owner->window), resizable != 0);
    gtk_container_add(GTK_CONTAINER(owner->window), owner->fixed);
    g_signal_connect(owner->window, "delete-event", G_CALLBACK(pudu_on_delete), owner);
    g_signal_connect(owner->window, "configure-event", G_CALLBACK(pudu_on_configure), owner);
    g_signal_connect(owner->window, "focus-in-event", G_CALLBACK(pudu_on_focus), owner);
    g_signal_connect(owner->window, "focus-out-event", G_CALLBACK(pudu_on_focus), owner);
    g_hash_table_insert(pudu_windows, pudu_key(id), owner);
    return PUDU_WEBVIEW_DONE;
  }
  PuduWindow *owner = g_hash_table_lookup(pudu_windows, &id);
  if (owner == NULL) {
    return pudu_refuse(PUDU_WEBVIEW_UNKNOWN, "window is not open");
  }
  GtkWindow *window = GTK_WINDOW(owner->window);
  int64_t a = 0, b = 0;
  gboolean pair = count == 5 && pudu_field_int(fields[3], &a) == 0 && pudu_field_int(fields[4], &b) == 0;
  if (pudu_field_is(fields[2], "title") && count == 4) {
    g_autofree char *title = pudu_field_copy(fields[3]);
    gtk_window_set_title(window, title == NULL ? "" : title);
  } else if (pudu_field_is(fields[2], "size") && pair) {
    gtk_window_resize(window, (int)a, (int)b);
  } else if (pudu_field_is(fields[2], "min-size") && pair) {
    GdkGeometry hints = {.min_width = (int)a, .min_height = (int)b};
    gtk_window_set_geometry_hints(window, NULL, &hints, GDK_HINT_MIN_SIZE);
  } else if (pudu_field_is(fields[2], "max-size") && pair) {
    GdkGeometry hints = {.max_width = a == 0 ? G_MAXINT : (int)a, .max_height = b == 0 ? G_MAXINT : (int)b};
    gtk_window_set_geometry_hints(window, NULL, &hints, GDK_HINT_MAX_SIZE);
  } else if (pudu_field_is(fields[2], "position") && pair) {
    gtk_window_move(window, (int)a, (int)b);
  } else if (pudu_field_is(fields[2], "center")) {
    gtk_window_set_position(window, GTK_WIN_POS_CENTER);
  } else if (pudu_field_is(fields[2], "show") || pudu_field_is(fields[2], "focus")) {
    gtk_widget_show_all(owner->window);
    gtk_window_present(window);
  } else if (pudu_field_is(fields[2], "hide")) {
    gtk_widget_hide(owner->window);
  } else if (pudu_field_is(fields[2], "fullscreen") && count == 4) {
    if (pudu_field_is(fields[3], "1")) {
      gtk_window_fullscreen(window);
    } else {
      gtk_window_unfullscreen(window);
    }
  } else if (pudu_field_is(fields[2], "close")) {
    GHashTableIter iter;
    gpointer key, value;
    g_hash_table_iter_init(&iter, pudu_views);
    while (g_hash_table_iter_next(&iter, &key, &value)) {
      if (((PuduView *)value)->window == id) {
        g_hash_table_iter_remove(&iter);
      }
    }
    gtk_widget_destroy(owner->window);
    g_hash_table_remove(pudu_windows, &id);
  } else {
    return pudu_refuse(PUDU_WEBVIEW_MALFORMED, "unknown window verb");
  }
  return PUDU_WEBVIEW_DONE;
}

PuduWindow *pudu_window_named(int64_t id) {
  return g_hash_table_lookup(pudu_windows, &id);
}

int32_t pudu_webview_send(const uint8_t *records, size_t length) {
  if (!pudu_ready()) {
    return pudu_started ? PUDU_WEBVIEW_NOT_MAIN : PUDU_WEBVIEW_UNSUPPORTED;
  }
  if (records == NULL && length > 0) {
    return PUDU_WEBVIEW_INVALID;
  }
  size_t cursor = 0;
  pudu_field fields[PUDU_RECORD_FIELDS];
  for (;;) {
    int count = pudu_record_next(records, length, &cursor, fields, PUDU_RECORD_FIELDS);
    if (count == 0) {
      return PUDU_WEBVIEW_DONE;
    }
    if (count < 0) {
      return pudu_refuse(PUDU_WEBVIEW_MALFORMED, "a command record is not framed");
    }
    int32_t status;
    if (pudu_field_is(fields[0], "window")) {
      status = pudu_window_command(fields, count);
    } else if (pudu_field_is(fields[0], "view")) {
      status = pudu_view_command(fields, count);
    } else if (pudu_field_is(fields[0], "app") || pudu_field_is(fields[0], "surface")) {
      status = pudu_refuse(PUDU_WEBVIEW_UNSUPPORTED, "native menus, dialogs and surfaces are not available on this platform");
    } else {
      status = pudu_refuse(PUDU_WEBVIEW_MALFORMED, "a record names neither a window nor a view");
    }
    if (status != PUDU_WEBVIEW_DONE) {
      return status;
    }
  }
}

static gboolean pudu_on_timeout(gpointer data) {
  *(gboolean *)data = TRUE;
  return G_SOURCE_REMOVE;
}

int32_t pudu_webview_pump(int32_t milliseconds) {
  if (!pudu_ready()) {
    return pudu_started ? PUDU_WEBVIEW_NOT_MAIN : PUDU_WEBVIEW_UNSUPPORTED;
  }
  if (milliseconds < 0) {
    return PUDU_WEBVIEW_INVALID;
  }
  gboolean expired = FALSE;
  guint timer = g_timeout_add((guint)milliseconds, pudu_on_timeout, &expired);
  while (pudu_events.length == 0 && !expired) {
    g_main_context_iteration(NULL, TRUE);
  }
  if (!expired) {
    g_source_remove(timer);
  }
  return pudu_events.length > 0 ? PUDU_WEBVIEW_QUEUED : PUDU_WEBVIEW_DONE;
}

int64_t pudu_webview_events(uint8_t *buffer, size_t capacity) {
  if (!pudu_ready()) {
    return pudu_started ? PUDU_WEBVIEW_NOT_MAIN : PUDU_WEBVIEW_UNSUPPORTED;
  }
  return pudu_buffer_drain(&pudu_events, buffer, capacity);
}

int64_t pudu_webview_body(int64_t request, uint8_t *buffer, size_t capacity) {
  if (!pudu_ready()) {
    return pudu_started ? PUDU_WEBVIEW_NOT_MAIN : PUDU_WEBVIEW_UNSUPPORTED;
  }
  PuduPending *pending = g_hash_table_lookup(pudu_pending, &request);
  if (pending == NULL) {
    return PUDU_WEBVIEW_GONE;
  }
  gsize size = 0;
  const void *data = pending->body == NULL ? NULL : g_bytes_get_data(pending->body, &size);
  if (buffer != NULL && size <= capacity && size > 0) {
    memcpy(buffer, data, size);
  }
  return (int64_t)size;
}

int64_t pudu_webview_failure(uint8_t *buffer, size_t capacity) {
  if (!pudu_ready()) {
    return pudu_started ? PUDU_WEBVIEW_NOT_MAIN : PUDU_WEBVIEW_UNSUPPORTED;
  }
  size_t size = pudu_failure == NULL ? 0 : strlen(pudu_failure);
  if (buffer != NULL && size <= capacity && size > 0) {
    memcpy(buffer, pudu_failure, size);
  }
  return (int64_t)size;
}
