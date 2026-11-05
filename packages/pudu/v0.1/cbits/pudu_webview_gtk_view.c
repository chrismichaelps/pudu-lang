#include "pudu_webview_gtk.h"

#include <string.h>

static char *pudu_view_label(PuduView *view) { return pudu_number(view->id); }

static void pudu_report2(const char *verb, PuduView *view) {
  g_autofree char *id = pudu_view_label(view);
  const char *fields[] = {verb, id};
  pudu_event(fields, 2);
}

static void pudu_report3(const char *verb, PuduView *view, const char *value) {
  g_autofree char *id = pudu_view_label(view);
  const char *fields[] = {verb, id, value == NULL ? "" : value};
  pudu_event(fields, 3);
}

static void pudu_collect_header(const char *name, const char *value, gpointer data) {
  g_string_append_printf((GString *)data, "%s: %s\n", name, value);
}

static void pudu_on_scheme(WebKitURISchemeRequest *request, gpointer data) {
  PuduView *view = data;
  int64_t identifier = pudu_next_request++;
  PuduPending *pending = g_new0(PuduPending, 1);
  pending->request = g_object_ref(request);
  GInputStream *stream = webkit_uri_scheme_request_get_http_body(request);
  if (stream != NULL) {
    GByteArray *collected = g_byte_array_new();
    guint8 chunk[65536];
    gssize read;
    while ((read = g_input_stream_read(stream, chunk, sizeof chunk, NULL, NULL)) > 0) {
      g_byte_array_append(collected, chunk, (guint)read);
    }
    pending->body = g_byte_array_free_to_bytes(collected);
    g_object_unref(stream);
  } else {
    pending->body = g_bytes_new(NULL, 0);
  }
  g_hash_table_insert(pudu_pending, pudu_key(identifier), pending);

  GString *headers = g_string_new(NULL);
  SoupMessageHeaders *sent = webkit_uri_scheme_request_get_http_headers(request);
  if (sent != NULL) {
    soup_message_headers_foreach(sent, pudu_collect_header, headers);
  }
  g_autofree char *id = pudu_view_label(view);
  g_autofree char *ticket = pudu_number(identifier);
  g_autofree char *size = pudu_number((int64_t)g_bytes_get_size(pending->body));
  const char *method = webkit_uri_scheme_request_get_http_method(request);
  const char *page = webkit_web_view_get_uri(webkit_uri_scheme_request_get_web_view(request));
  const char *fields[] = {
      "request", id, ticket, method == NULL ? "GET" : method, webkit_uri_scheme_request_get_uri(request),
      headers->str, size, page == NULL ? "" : page};
  pudu_event(fields, 8);
  g_string_free(headers, TRUE);
}

int32_t pudu_webview_respond(
    int64_t request,
    int32_t status,
    const uint8_t *head,
    size_t head_length,
    const uint8_t *body,
    size_t body_length) {
  if (status < 100 || status > 599 || (body == NULL && body_length > 0)) {
    return PUDU_WEBVIEW_INVALID;
  }
  PuduPending *pending = g_hash_table_lookup(pudu_pending, &request);
  if (pending == NULL) {
    return PUDU_WEBVIEW_GONE;
  }
  GBytes *bytes = g_bytes_new(body, body_length);
  GInputStream *stream = g_memory_input_stream_new_from_bytes(bytes);
  WebKitURISchemeResponse *response = webkit_uri_scheme_response_new(stream, (gint64)body_length);
  webkit_uri_scheme_response_set_status(response, (guint)status, NULL);
  SoupMessageHeaders *headers = soup_message_headers_new(SOUP_MESSAGE_HEADERS_RESPONSE);
  g_autofree char *text = g_strndup((const char *)head, head_length);
  g_auto(GStrv) lines = g_strsplit(text, "\n", -1);
  for (int i = 0; lines[i] != NULL; i++) {
    char *colon = strchr(lines[i], ':');
    if (colon == NULL || colon == lines[i]) {
      continue;
    }
    *colon = 0;
    if (g_ascii_strcasecmp(lines[i], "content-type") == 0) {
      webkit_uri_scheme_response_set_content_type(response, g_strstrip(colon + 1));
    }
    soup_message_headers_append(headers, lines[i], g_strstrip(colon + 1));
  }
  webkit_uri_scheme_response_set_http_headers(response, headers);
  webkit_uri_scheme_request_finish_with_response(pending->request, response);
  g_object_unref(response);
  g_object_unref(stream);
  g_bytes_unref(bytes);
  g_object_unref(pending->request);
  g_bytes_unref(pending->body);
  g_hash_table_remove(pudu_pending, &request);
  return PUDU_WEBVIEW_DONE;
}

static gboolean pudu_allows(PuduView *view, const char *uri) {
  if (g_str_has_prefix(uri, "pudu:") || g_str_has_prefix(uri, "about:") || g_str_has_prefix(uri, "data:") ||
      g_str_has_prefix(uri, "blob:")) {
    return TRUE;
  }
  for (guint i = 0; i < view->allowed->len; i++) {
    if (pudu_pattern_match(g_ptr_array_index(view->allowed, i), uri)) {
      return TRUE;
    }
  }
  return FALSE;
}

static gboolean pudu_on_policy(WebKitWebView *web, WebKitPolicyDecision *decision, WebKitPolicyDecisionType type, gpointer data) {
  (void)web;
  PuduView *view = data;
  if (type != WEBKIT_POLICY_DECISION_TYPE_NAVIGATION_ACTION && type != WEBKIT_POLICY_DECISION_TYPE_NEW_WINDOW_ACTION) {
    return FALSE;
  }
  WebKitNavigationAction *action = webkit_navigation_policy_decision_get_navigation_action(WEBKIT_NAVIGATION_POLICY_DECISION(decision));
  const char *uri = webkit_uri_request_get_uri(webkit_navigation_action_get_request(action));
  if (type == WEBKIT_POLICY_DECISION_TYPE_NEW_WINDOW_ACTION) {
    pudu_report3("new-window-blocked", view, uri);
    webkit_policy_decision_ignore(decision);
  } else if (pudu_allows(view, uri)) {
    webkit_policy_decision_use(decision);
  } else {
    pudu_report3("navigation-blocked", view, uri);
    webkit_policy_decision_ignore(decision);
  }
  return TRUE;
}

static void pudu_on_load(WebKitWebView *web, WebKitLoadEvent event, gpointer data) {
  if (event == WEBKIT_LOAD_COMMITTED) {
    pudu_report3("navigated", data, webkit_web_view_get_uri(web));
  } else if (event == WEBKIT_LOAD_FINISHED) {
    pudu_report3("loaded", data, webkit_web_view_get_uri(web));
  }
}

static void pudu_on_title(GObject *object, GParamSpec *spec, gpointer data) {
  (void)spec;
  pudu_report3("title", data, webkit_web_view_get_title(WEBKIT_WEB_VIEW(object)));
}

static void pudu_on_crash(WebKitWebView *web, WebKitWebProcessTerminationReason reason, gpointer data) {
  (void)web;
  (void)reason;
  pudu_report2("crashed", data);
}

/* The page a view was configured with, loaded only once every rule list is
   in place, so no request escapes rules that were still compiling. */
static void pudu_load_initial(PuduView *view) {
  WebKitWebView *web = WEBKIT_WEB_VIEW(view->web);
  if (view->html != NULL) {
    webkit_web_view_load_html(web, view->html, "pudu://app/");
  } else if (view->url != NULL) {
    webkit_web_view_load_uri(web, view->url);
  }
}

static void pudu_on_rules(GObject *source, GAsyncResult *result, gpointer data) {
  PuduView *view = data;
  GError *error = NULL;
  WebKitUserContentFilter *filter = webkit_user_content_filter_store_save_finish(WEBKIT_USER_CONTENT_FILTER_STORE(source), result, &error);
  if (filter != NULL) {
    webkit_user_content_manager_add_filter(view->content, filter);
    pudu_report3("rules", view, "ready");
    webkit_user_content_filter_unref(filter);
  } else {
    view->rules_failed = TRUE;
    g_autofree char *id = pudu_view_label(view);
    const char *fields[] = {"rules", id, "failed", error == NULL ? "failed" : error->message};
    pudu_event(fields, 4);
    g_clear_error(&error);
  }
  if (--view->rules_outstanding == 0 && !view->rules_failed && view->web != NULL) {
    pudu_load_initial(view);
  }
}

static WebKitWebContext *pudu_context(PuduView *view) {
  WebKitWebsiteDataManager *data;
  if (view->ephemeral) {
    data = webkit_website_data_manager_new_ephemeral();
  } else {
    /* The directory is named by a digest of the label, so no label can name a
       path outside the application's own data directory. */
    g_autofree char *label = g_compute_checksum_for_string(G_CHECKSUM_SHA256, view->store == NULL ? "default" : view->store, -1);
    g_autofree char *base = g_build_filename(g_get_user_data_dir(), g_get_prgname(), "webview", label, NULL);
    g_autofree char *cache = g_build_filename(g_get_user_cache_dir(), g_get_prgname(), "webview", label, NULL);
    data = webkit_website_data_manager_new("base-data-directory", base, "base-cache-directory", cache, NULL);
  }
  WebKitWebContext *context = webkit_web_context_new_with_website_data_manager(data);
  g_object_unref(data);
  WebKitSecurityManager *security = webkit_web_context_get_security_manager(context);
  webkit_security_manager_register_uri_scheme_as_secure(security, "pudu");
  webkit_security_manager_register_uri_scheme_as_cors_enabled(security, "pudu");
  webkit_web_context_register_uri_scheme(context, "pudu", pudu_on_scheme, view, NULL);
  return context;
}

static int32_t pudu_realize(PuduView *view) {
  PuduWindow *owner = pudu_window_named(view->window);
  if (owner == NULL) {
    return pudu_refuse(PUDU_WEBVIEW_UNKNOWN, "the view's window is closed");
  }
  WebKitWebContext *context = pudu_context(view);
  view->content = webkit_user_content_manager_new();
  for (guint i = 0; i < view->scripts->len; i++) {
    webkit_user_content_manager_add_script(view->content, g_ptr_array_index(view->scripts, i));
  }
  WebKitSettings *settings = webkit_settings_new();
  webkit_settings_set_enable_developer_extras(settings, view->devtools);
  if (view->agent != NULL) {
    webkit_settings_set_user_agent(settings, view->agent);
  }
  view->web = GTK_WIDGET(g_object_new(WEBKIT_TYPE_WEB_VIEW, "web-context", context, "user-content-manager", view->content, "settings", settings, NULL));
  g_object_unref(settings);
  g_object_unref(context);
  WebKitWebView *web = WEBKIT_WEB_VIEW(view->web);
  if (view->zoom > 0) {
    webkit_web_view_set_zoom_level(web, view->zoom);
  }
  if (view->transparent) {
    GdkRGBA clear = {0, 0, 0, 0};
    webkit_web_view_set_background_color(web, &clear);
  }
  g_signal_connect(web, "decide-policy", G_CALLBACK(pudu_on_policy), view);
  g_signal_connect(web, "load-changed", G_CALLBACK(pudu_on_load), view);
  g_signal_connect(web, "notify::title", G_CALLBACK(pudu_on_title), view);
  g_signal_connect(web, "web-process-terminated", G_CALLBACK(pudu_on_crash), view);
  int width = view->fill ? owner->width : view->width;
  int height = view->fill ? owner->height : view->height;
  gtk_widget_set_size_request(view->web, width, height);
  gtk_fixed_put(GTK_FIXED(owner->fixed), view->web, view->fill ? 0 : view->x, view->fill ? 0 : view->y);
  gtk_widget_show(view->web);
  view->rules_outstanding = view->rules->len;
  if (view->rules->len == 0) {
    pudu_load_initial(view);
  } else {
    g_autofree char *path = g_build_filename(g_get_user_cache_dir(), g_get_prgname(), "content-rules", NULL);
    WebKitUserContentFilterStore *store = webkit_user_content_filter_store_new(path);
    for (guint i = 0; i < view->rules->len; i++) {
      g_autofree char *name = g_strdup_printf("pudu-%lld-%u", (long long)view->id, i);
      const char *source = g_ptr_array_index(view->rules, i);
      GBytes *bytes = g_bytes_new(source, strlen(source));
      webkit_user_content_filter_store_save(store, name, bytes, NULL, pudu_on_rules, view);
      g_bytes_unref(bytes);
    }
    g_object_unref(store);
  }
  return PUDU_WEBVIEW_DONE;
}

static WebKitUserScript *pudu_style(const char *css) {
  g_autofree char *literal = g_strescape(css, NULL);
  g_autofree char *source = g_strdup_printf(
      "(function(){var s=document.createElement('style');s.textContent=\"%s\";"
      "var put=function(){(document.head||document.documentElement).appendChild(s)};"
      "if(document.documentElement){put()}else{document.addEventListener('DOMContentLoaded',put)}})();",
      literal);
  return webkit_user_script_new(source, WEBKIT_USER_CONTENT_INJECT_TOP_FRAME, WEBKIT_USER_SCRIPT_INJECT_AT_DOCUMENT_START, NULL, NULL);
}

static int32_t pudu_configure(PuduView *view, pudu_field *fields, int count) {
  g_autofree char *value = count > 3 ? pudu_field_copy(fields[3]) : NULL;
  if (count > 3 && value == NULL) {
    return pudu_refuse(PUDU_WEBVIEW_MALFORMED, "a configuration value holds NUL");
  }
  pudu_field verb = fields[2];
  if (pudu_field_is(verb, "url") && count == 4) {
    view->url = g_strdup(value);
  } else if (pudu_field_is(verb, "html") && count == 4) {
    view->html = g_strdup(value);
  } else if (pudu_field_is(verb, "devtools") && count == 4) {
    view->devtools = g_strcmp0(value, "1") == 0;
  } else if (pudu_field_is(verb, "user-agent") && count == 4) {
    view->agent = g_strdup(value);
  } else if (pudu_field_is(verb, "zoom") && count == 4) {
    view->zoom = g_ascii_strtod(value, NULL) / 1000.0;
  } else if (pudu_field_is(verb, "data-store") && count == 4) {
    view->store = g_strdup(value);
  } else if (pudu_field_is(verb, "ephemeral") && count == 3) {
    view->ephemeral = TRUE;
  } else if (pudu_field_is(verb, "transparent") && count == 3) {
    view->transparent = TRUE;
  } else if (pudu_field_is(verb, "navigation-allow") && count == 4) {
    g_ptr_array_add(view->allowed, g_strdup(value));
  } else if (pudu_field_is(verb, "rules") && count == 4) {
    g_ptr_array_add(view->rules, g_strdup(value));
  } else if (pudu_field_is(verb, "style") && count == 4) {
    g_ptr_array_add(view->scripts, pudu_style(value));
  } else if (pudu_field_is(verb, "script") && count == 6) {
    WebKitUserScriptInjectionTime time = pudu_field_is(fields[4], "end") ? WEBKIT_USER_SCRIPT_INJECT_AT_DOCUMENT_END : WEBKIT_USER_SCRIPT_INJECT_AT_DOCUMENT_START;
    WebKitUserContentInjectedFrames frames = pudu_field_is(fields[5], "all") ? WEBKIT_USER_CONTENT_INJECT_ALL_FRAMES : WEBKIT_USER_CONTENT_INJECT_TOP_FRAME;
    g_ptr_array_add(view->scripts, webkit_user_script_new(value, frames, time, NULL, NULL));
  } else {
    return pudu_refuse(PUDU_WEBVIEW_MALFORMED, "unknown view configuration");
  }
  return PUDU_WEBVIEW_DONE;
}

typedef struct {
  PuduView *view;
  char *ticket;
} PuduEvaluation;

static void pudu_on_evaluated(GObject *source, GAsyncResult *result, gpointer data) {
  PuduEvaluation *evaluation = data;
  GError *error = NULL;
  JSCValue *value = webkit_web_view_evaluate_javascript_finish(WEBKIT_WEB_VIEW(source), result, &error);
  g_autofree char *id = pudu_view_label(evaluation->view);
  if (value == NULL) {
    const char *fields[] = {"eval", id, evaluation->ticket, "error", error == NULL ? "failed" : error->message};
    pudu_event(fields, 5);
    g_clear_error(&error);
  } else {
    g_autofree char *text = jsc_value_is_string(value) ? jsc_value_to_string(value)
                            : (jsc_value_is_undefined(value) || jsc_value_is_null(value)) ? g_strdup("null")
                                                                                          : jsc_value_to_json(value, 0);
    const char *fields[] = {"eval", id, evaluation->ticket, "ok", text == NULL ? "null" : text};
    pudu_event(fields, 5);
    g_object_unref(value);
  }
  g_free(evaluation->ticket);
  g_free(evaluation);
}

static int32_t pudu_operate(PuduView *view, pudu_field *fields, int count) {
  WebKitWebView *web = WEBKIT_WEB_VIEW(view->web);
  g_autofree char *value = count > 3 ? pudu_field_copy(fields[3]) : NULL;
  pudu_field verb = fields[2];
  if (pudu_field_is(verb, "navigate") && count == 4 && value != NULL) {
    webkit_web_view_load_uri(web, value);
  } else if (pudu_field_is(verb, "html") && count == 4 && value != NULL) {
    webkit_web_view_load_html(web, value, "pudu://app/");
  } else if (pudu_field_is(verb, "reload")) {
    webkit_web_view_reload(web);
  } else if (pudu_field_is(verb, "back")) {
    webkit_web_view_go_back(web);
  } else if (pudu_field_is(verb, "forward")) {
    webkit_web_view_go_forward(web);
  } else if (pudu_field_is(verb, "stop")) {
    webkit_web_view_stop_loading(web);
  } else if (pudu_field_is(verb, "eval") && count == 5 && value != NULL) {
    g_autofree char *source = pudu_field_copy(fields[4]);
    PuduEvaluation *evaluation = g_new0(PuduEvaluation, 1);
    evaluation->view = view;
    evaluation->ticket = g_strdup(value);
    webkit_web_view_evaluate_javascript(web, source == NULL ? "" : source, -1, NULL, NULL, NULL, pudu_on_evaluated, evaluation);
  } else if (pudu_field_is(verb, "bounds") && count == 7) {
    int64_t x = 0, y = 0, width = 0, height = 0;
    if (pudu_field_int(fields[3], &x) != 0 || pudu_field_int(fields[4], &y) != 0 || pudu_field_int(fields[5], &width) != 0 ||
        pudu_field_int(fields[6], &height) != 0) {
      return pudu_refuse(PUDU_WEBVIEW_MALFORMED, "bounds needs four numbers");
    }
    view->fill = FALSE;
    gtk_fixed_move(GTK_FIXED(gtk_widget_get_parent(view->web)), view->web, (int)x, (int)y);
    gtk_widget_set_size_request(view->web, (int)width, (int)height);
  } else if (pudu_field_is(verb, "zoom") && count == 4 && value != NULL) {
    webkit_web_view_set_zoom_level(web, g_ascii_strtod(value, NULL) / 1000.0);
  } else if (pudu_field_is(verb, "user-agent") && count == 4 && value != NULL) {
    webkit_settings_set_user_agent(webkit_web_view_get_settings(web), value);
  } else if (pudu_field_is(verb, "devtools-open")) {
    webkit_web_inspector_show(webkit_web_view_get_inspector(web));
  } else if (pudu_field_is(verb, "devtools-close")) {
    webkit_web_inspector_close(webkit_web_view_get_inspector(web));
  } else if (pudu_field_is(verb, "show")) {
    gtk_widget_show(view->web);
  } else if (pudu_field_is(verb, "hide")) {
    gtk_widget_hide(view->web);
  } else if (pudu_field_is(verb, "focus")) {
    gtk_widget_grab_focus(view->web);
  } else if (pudu_field_is(verb, "close")) {
    gtk_widget_destroy(view->web);
    view->web = NULL;
    g_hash_table_remove(pudu_views, &view->id);
  } else {
    return pudu_refuse(PUDU_WEBVIEW_MALFORMED, "unknown view command");
  }
  return PUDU_WEBVIEW_DONE;
}

int32_t pudu_view_command(pudu_field *fields, int count) {
  int64_t id = 0;
  if (count < 3 || pudu_field_int(fields[1], &id) != 0) {
    return pudu_refuse(PUDU_WEBVIEW_MALFORMED, "view record needs an id and a verb");
  }
  if (pudu_field_is(fields[2], "create")) {
    int64_t window = 0, x = 0, y = 0, width = 0, height = 0, fill = 0;
    if (count != 9 || pudu_field_int(fields[3], &window) != 0 || pudu_field_int(fields[4], &x) != 0 ||
        pudu_field_int(fields[5], &y) != 0 || pudu_field_int(fields[6], &width) != 0 || pudu_field_int(fields[7], &height) != 0 ||
        pudu_field_int(fields[8], &fill) != 0 || width < 0 || height < 0) {
      return pudu_refuse(PUDU_WEBVIEW_MALFORMED, "view create needs a window, a frame and a fill flag");
    }
    if (g_hash_table_contains(pudu_views, &id)) {
      return pudu_refuse(PUDU_WEBVIEW_INVALID, "view id is already in use");
    }
    if (pudu_window_named(window) == NULL) {
      return pudu_refuse(PUDU_WEBVIEW_UNKNOWN, "view create names a window that is not open");
    }
    PuduView *view = g_new0(PuduView, 1);
    view->id = id;
    view->window = window;
    view->x = (int)x;
    view->y = (int)y;
    view->width = (int)width;
    view->height = (int)height;
    view->fill = fill != 0;
    view->scripts = g_ptr_array_new_with_free_func((GDestroyNotify)webkit_user_script_unref);
    view->allowed = g_ptr_array_new_with_free_func(g_free);
    view->rules = g_ptr_array_new_with_free_func(g_free);
    g_hash_table_insert(pudu_views, pudu_key(id), view);
    return PUDU_WEBVIEW_DONE;
  }
  PuduView *view = g_hash_table_lookup(pudu_views, &id);
  if (view == NULL) {
    return pudu_refuse(PUDU_WEBVIEW_UNKNOWN, "view does not exist");
  }
  if (pudu_field_is(fields[2], "realize")) {
    if (view->web != NULL) {
      return pudu_refuse(PUDU_WEBVIEW_INVALID, "the view is already realized");
    }
    return pudu_realize(view);
  }
  if (view->web == NULL) {
    if (pudu_field_is(fields[2], "close")) {
      g_hash_table_remove(pudu_views, &id);
      return PUDU_WEBVIEW_DONE;
    }
    return pudu_configure(view, fields, count);
  }
  return pudu_operate(view, fields, count);
}
