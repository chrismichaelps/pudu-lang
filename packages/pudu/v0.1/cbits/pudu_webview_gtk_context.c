#include "pudu_webview_gtk.h"

static GHashTable *pudu_stores;

static WebKitWebContext *pudu_context_new(WebKitWebsiteDataManager *data) {
  WebKitWebContext *context = webkit_web_context_new_with_website_data_manager(data);
  WebKitSecurityManager *security = webkit_web_context_get_security_manager(context);
  webkit_security_manager_register_uri_scheme_as_secure(security, "pudu");
  webkit_security_manager_register_uri_scheme_as_cors_enabled(security, "pudu");
  webkit_web_context_register_uri_scheme(context, "pudu", pudu_scheme_request, NULL, NULL);
  return context;
}

WebKitWebContext *pudu_view_context(PuduView *view) {
  if (view->ephemeral || view->store == NULL) {
    WebKitWebsiteDataManager *data = webkit_website_data_manager_new_ephemeral();
    WebKitWebContext *context = pudu_context_new(data);
    g_object_unref(data);
    return context;
  }
  if (pudu_stores == NULL)
    pudu_stores = g_hash_table_new_full(g_str_hash, g_str_equal, g_free, g_object_unref);
  WebKitWebContext *context = g_hash_table_lookup(pudu_stores, view->store);
  if (context == NULL) {
    g_autofree char *label = g_compute_checksum_for_string(G_CHECKSUM_SHA256, view->store, -1);
    const char *program = g_get_prgname();
    if (program == NULL || program[0] == 0) program = "pudu";
    g_autofree char *base = g_build_filename(g_get_user_data_dir(), program, "webview", label, NULL);
    g_autofree char *cache = g_build_filename(g_get_user_cache_dir(), program, "webview", label, NULL);
    WebKitWebsiteDataManager *data = webkit_website_data_manager_new(
      "base-data-directory", base, "base-cache-directory", cache, NULL);
    context = pudu_context_new(data);
    g_object_unref(data);
    g_hash_table_insert(pudu_stores, g_strdup(view->store), context);
  }
  return g_object_ref(context);
}
