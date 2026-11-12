#include "pudu_webview_gtk.h"

#include <string.h>

static char *pudu_origin(const char *text) {
  GUri *uri = g_uri_parse(text == NULL ? "" : text, G_URI_FLAGS_PARSE_RELAXED, NULL);
  if (uri == NULL || g_uri_get_scheme(uri) == NULL || g_uri_get_host(uri) == NULL) {
    if (uri != NULL) g_uri_unref(uri);
    return NULL;
  }
  g_autofree char *scheme = g_ascii_strdown(g_uri_get_scheme(uri), -1);
  g_autofree char *host = g_ascii_strdown(g_uri_get_host(uri), -1);
  char *origin = g_uri_join(G_URI_FLAGS_NONE, scheme, NULL, host, g_uri_get_port(uri), "", NULL, NULL);
  g_uri_unref(uri);
  return origin;
}

int32_t pudu_view_authority(PuduView *view, pudu_field *fields, int count) {
  if (count != 6 || !(pudu_field_is(fields[3], "drag") || pudu_field_is(fields[3], "toggle-maximize")))
    return pudu_refuse(PUDU_WEBVIEW_MALFORMED, "window-authority needs an action, origin and bridge key");
  g_autofree char *action = pudu_field_copy(fields[3]);
  g_autofree char *origin = pudu_field_copy(fields[4]);
  g_autofree char *key = pudu_field_copy(fields[5]);
  g_autofree char *canonical = pudu_origin(origin);
  if (canonical == NULL || g_strcmp0(origin, canonical) != 0 || key == NULL || strlen(key) != 32)
    return pudu_refuse(PUDU_WEBVIEW_MALFORMED, "window-authority needs an exact origin and a 128-bit bridge key");
  for (int i = 0; i < 32; i++)
    if (!g_ascii_isxdigit(key[i])) return pudu_refuse(PUDU_WEBVIEW_MALFORMED, "bridge key must be hexadecimal");
  if (view->native_key != NULL && strcmp(view->native_key, key) != 0)
    return pudu_refuse(PUDU_WEBVIEW_INVALID, "window authority cannot replace the view's bridge key");
  if (view->native_key == NULL) view->native_key = g_strdup(key);
  g_hash_table_replace(view->window_actions, g_strdup(action), g_strdup(origin));
  return PUDU_WEBVIEW_DONE;
}

static gboolean pudu_press(GtkWidget *widget, GdkEventButton *event, gpointer data) {
  (void)widget;
  PuduView *view = data;
  if (view->press != NULL) gdk_event_free(view->press);
  view->press = event->button == 1 ? gdk_event_copy((GdkEvent *)event) : NULL;
  return FALSE;
}

static gboolean pudu_release(GtkWidget *widget, GdkEventButton *event, gpointer data) {
  (void)widget;
  (void)event;
  PuduView *view = data;
  if (view->press != NULL) gdk_event_free(view->press);
  view->press = NULL;
  return FALSE;
}

static char *pudu_member(JSCValue *object, const char *name) {
  JSCValue *value = jsc_value_object_get_property(object, name);
  char *text = jsc_value_is_string(value) ? jsc_value_to_string(value) : NULL;
  g_object_unref(value);
  return text;
}

static gboolean pudu_native_message(WebKitUserContentManager *content, JSCValue *message,
    WebKitScriptMessageReply *reply, gpointer data) {
  (void)content;
  PuduView *view = data;
  JSCContext *context = jsc_value_get_context(message);
  gboolean accepted = FALSE;
  if (view->web != NULL && view->native_key != NULL && jsc_value_is_string(message)) {
    g_autofree char *text = jsc_value_to_string(message);
    JSCValue *object = jsc_value_new_from_json(context, text);
    if (object != NULL && jsc_value_is_object(object)) {
      g_autofree char *key = pudu_member(object, "key");
      g_autofree char *origin = pudu_member(object, "origin");
      g_autofree char *action = pudu_member(object, "action");
      const char *allowed = action == NULL ? NULL : g_hash_table_lookup(view->window_actions, action);
      g_autofree char *current = pudu_origin(webkit_web_view_get_uri(WEBKIT_WEB_VIEW(view->web)));
      PuduWindow *owner = pudu_window_named(view->window);
      if (owner != NULL && allowed != NULL && g_strcmp0(key, view->native_key) == 0 &&
          g_strcmp0(origin, allowed) == 0 && g_strcmp0(current, allowed) == 0) {
        if (strcmp(action, "toggle-maximize") == 0) {
          GdkWindow *window = gtk_widget_get_window(owner->window);
          if (window != NULL && (gdk_window_get_state(window) & GDK_WINDOW_STATE_MAXIMIZED))
            gtk_window_unmaximize(GTK_WINDOW(owner->window));
          else gtk_window_maximize(GTK_WINDOW(owner->window));
          accepted = TRUE;
        } else if (view->press != NULL && gtk_window_is_active(GTK_WINDOW(owner->window)) && gtk_widget_get_mapped(view->web)) {
          GdkEventButton *press = &view->press->button;
          GdkDevice *device = gdk_event_get_device(view->press);
          GdkModifierType buttons = 0;
          if (device != NULL && !gdk_window_is_destroyed(press->window))
            gdk_window_get_device_position(press->window, device, NULL, NULL, &buttons);
          if ((buttons & GDK_BUTTON1_MASK) != 0) {
            gtk_window_begin_move_drag(GTK_WINDOW(owner->window), 1, (int)press->x_root, (int)press->y_root, press->time);
            accepted = TRUE;
          }
        }
      }
    }
    if (object != NULL) g_object_unref(object);
    else jsc_context_clear_exception(context);
  }
  JSCValue *result = jsc_value_new_boolean(context, accepted);
  webkit_script_message_reply_return_value(reply, result);
  g_object_unref(result);
  return TRUE;
}

static void pudu_drop_event(PuduView *view, const char *verb, int x, int y, const char *paths) {
  g_autofree char *id = pudu_number(view->id), *sx = pudu_number(x), *sy = pudu_number(y);
  const char *fields[] = {verb, id, sx, sy, paths};
  pudu_event(fields, paths == NULL ? 4 : 5);
}

static gboolean pudu_drop_motion(GtkWidget *widget, GdkDragContext *context, gint x, gint y, guint time, gpointer data) {
  (void)widget;
  PuduView *view = data;
  if (!view->drop_inside) pudu_drop_event(view, "drop-enter", x, y, "[]");
  else pudu_drop_event(view, "drop-over", x, y, NULL);
  view->drop_inside = TRUE;
  gdk_drag_status(context, GDK_ACTION_COPY, time);
  return TRUE;
}

static void pudu_drop_leave(GtkWidget *widget, GdkDragContext *context, guint time, gpointer data) {
  (void)widget;
  (void)context;
  (void)time;
  PuduView *view = data;
  view->drop_inside = FALSE;
  g_autofree char *id = pudu_number(view->id);
  const char *fields[] = {"drop-leave", id};
  pudu_event(fields, 2);
}

static void pudu_drop_received(GtkWidget *widget, GdkDragContext *drag, gint x, gint y,
    GtkSelectionData *selection, guint info, guint time, gpointer data) {
  (void)widget;
  (void)info;
  PuduView *view = data;
  g_auto(GStrv) uris = gtk_selection_data_get_uris(selection);
  JSCContext *context = jsc_context_new();
  JSCValue *array = jsc_value_new_array(context, G_TYPE_NONE);
  guint index = 0;
  gboolean valid = uris != NULL;
  if (uris != NULL) for (int i = 0; uris[i] != NULL; i++) {
    g_autofree char *host = NULL;
    g_autofree char *path = g_filename_from_uri(uris[i], &host, NULL);
    if (path == NULL || !g_utf8_validate(path, -1, NULL) ||
        (host != NULL && host[0] != 0 && g_ascii_strcasecmp(host, "localhost") != 0)) {
      valid = FALSE;
      break;
    }
    JSCValue *value = jsc_value_new_string(context, path);
    jsc_value_object_set_property_at_index(array, index++, value);
    g_object_unref(value);
  }
  g_autofree char *paths = jsc_value_to_json(array, 0);
  if (valid && index > 0) pudu_drop_event(view, "drop", x, y, paths);
  gtk_drag_finish(drag, valid && index > 0, FALSE, time);
  g_signal_stop_emission_by_name(widget, "drag-data-received");
  view->drop_inside = FALSE;
  g_object_unref(array);
  g_object_unref(context);
}

static void pudu_inspector_event(PuduView *view, gboolean open);

static gboolean pudu_inspector_opened(WebKitWebInspector *inspector, gpointer data) {
  (void)inspector;
  PuduView *view = data;
  view->inspector_open = TRUE;
  view->inspector_requested = TRUE;
  pudu_inspector_event(view, TRUE);
  return FALSE;
}

static void pudu_inspector_closed(WebKitWebInspector *inspector, gpointer data) {
  (void)inspector;
  PuduView *view = data;
  view->inspector_open = FALSE;
  view->inspector_requested = FALSE;
  pudu_inspector_event(view, FALSE);
}

void pudu_view_interaction(PuduView *view) {
  WebKitWebInspector *inspector = webkit_web_view_get_inspector(WEBKIT_WEB_VIEW(view->web));
  g_signal_connect(inspector, "open-window", G_CALLBACK(pudu_inspector_opened), view);
  g_signal_connect(inspector, "closed", G_CALLBACK(pudu_inspector_closed), view);
  webkit_user_content_manager_register_script_message_handler_with_reply(view->content, "puduWindowAuthorized", NULL);
  g_signal_connect(view->content, "script-message-with-reply-received::puduWindowAuthorized", G_CALLBACK(pudu_native_message), view);
  gtk_widget_add_events(view->web, GDK_BUTTON_PRESS_MASK | GDK_BUTTON_RELEASE_MASK);
  g_signal_connect(view->web, "button-press-event", G_CALLBACK(pudu_press), view);
  g_signal_connect(view->web, "button-release-event", G_CALLBACK(pudu_release), view);
  g_signal_connect(view->web, "focus-out-event", G_CALLBACK(pudu_release), view);
  if (view->file_drop) {
    GtkTargetEntry targets[] = {{"text/uri-list", 0, 0}};
    gtk_drag_dest_set(view->web, GTK_DEST_DEFAULT_DROP, targets, 1, GDK_ACTION_COPY);
    g_signal_connect(view->web, "drag-motion", G_CALLBACK(pudu_drop_motion), view);
    g_signal_connect(view->web, "drag-leave", G_CALLBACK(pudu_drop_leave), view);
    g_signal_connect(view->web, "drag-data-received", G_CALLBACK(pudu_drop_received), view);
  }
}

void pudu_view_closed(PuduView *view) {
  GtkWidget *web = view->web;
  view->web = NULL;
  if (view->press != NULL) gdk_event_free(view->press);
  view->press = NULL;
  g_clear_pointer(&view->native_key, g_free);
  g_hash_table_remove_all(view->window_actions);
  if (web != NULL) gtk_widget_destroy(web);
}

static void pudu_inspector_event(PuduView *view, gboolean open) {
  g_autofree char *id = pudu_number(view->id);
  const char *fields[] = {"devtools", id, open ? "open" : "closed"};
  pudu_event(fields, 3);
}

static void pudu_cleared(GObject *source, GAsyncResult *result, gpointer data) {
  int64_t *identifier = data;
  GError *error = NULL;
  gboolean cleared = webkit_website_data_manager_clear_finish(WEBKIT_WEBSITE_DATA_MANAGER(source), result, &error);
  g_autofree char *id = pudu_number(*identifier);
  const char *fields[] = {cleared ? "data-cleared" : "data-clear-failed", id, error == NULL ? "website data could not be cleared" : error->message};
  pudu_event(fields, cleared ? 2 : 3);
  g_clear_error(&error);
  g_free(identifier);
}

int32_t pudu_view_extra(PuduView *view, pudu_field *fields, int count) {
  if (count != 3) return pudu_refuse(PUDU_WEBVIEW_MALFORMED, "view action takes no values");
  WebKitWebView *web = WEBKIT_WEB_VIEW(view->web);
  pudu_field verb = fields[2];
  if (pudu_field_is(verb, "devtools-open") || pudu_field_is(verb, "devtools-close") ||
      pudu_field_is(verb, "devtools-toggle") || pudu_field_is(verb, "devtools-state")) {
    if (!view->devtools) return pudu_refuse(PUDU_WEBVIEW_UNSUPPORTED, "developer tools are disabled for this view");
    WebKitWebInspector *inspector = webkit_web_view_get_inspector(web);
    gboolean open = view->inspector_open;
    if (!pudu_field_is(verb, "devtools-state")) {
      gboolean wanted = pudu_field_is(verb, "devtools-open") || (pudu_field_is(verb, "devtools-toggle") && !view->inspector_requested);
      view->inspector_requested = wanted;
      if (wanted) webkit_web_inspector_show(inspector);
      else webkit_web_inspector_close(inspector);
      open = view->inspector_open;
    }
    pudu_inspector_event(view, open);
  } else if (pudu_field_is(verb, "print")) {
    WebKitPrintOperation *operation = webkit_print_operation_new(web);
    PuduWindow *owner = pudu_window_named(view->window);
    webkit_print_operation_run_dialog(operation, owner == NULL ? NULL : GTK_WINDOW(owner->window));
    g_object_unref(operation);
  } else if (pudu_field_is(verb, "clear-data")) {
    WebKitWebsiteDataManager *manager = webkit_web_context_get_website_data_manager(webkit_web_view_get_context(web));
    webkit_website_data_manager_clear(manager, WEBKIT_WEBSITE_DATA_ALL, 0, NULL, pudu_cleared, pudu_key(view->id));
  } else return pudu_refuse(PUDU_WEBVIEW_MALFORMED, "unknown view command");
  return PUDU_WEBVIEW_DONE;
}
