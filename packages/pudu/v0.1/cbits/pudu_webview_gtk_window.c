#include "pudu_webview_gtk.h"

#include <string.h>

typedef struct { GtkFixed parent; } PuduFixed;
typedef struct { GtkFixedClass parent; } PuduFixedClass;
G_DEFINE_TYPE(PuduFixed, pudu_fixed, GTK_TYPE_FIXED)

static void pudu_fixed_preferred(GtkWidget *widget, gint *minimum, gint *natural) {
  (void)widget;
  if (minimum != NULL) *minimum = 0;
  if (natural != NULL) *natural = 0;
}

static void pudu_fixed_class_init(PuduFixedClass *type) {
  GtkWidgetClass *widget = GTK_WIDGET_CLASS(type);
  widget->get_preferred_width = pudu_fixed_preferred;
  widget->get_preferred_height = pudu_fixed_preferred;
}

static void pudu_fixed_init(PuduFixed *fixed) { (void)fixed; }

GtkWidget *pudu_fixed_new(void) { return g_object_new(pudu_fixed_get_type(), NULL); }

static const char *pudu_flag(gboolean value) { return value ? "1" : "0"; }

static void pudu_theme(void) {
  gboolean preferred = FALSE;
  g_autofree char *name = NULL;
  g_object_get(gtk_settings_get_default(), "gtk-application-prefer-dark-theme", &preferred, "gtk-theme-name", &name, NULL);
  g_autofree char *lower = g_ascii_strdown(name == NULL ? "" : name, -1);
  const char *fields[] = {"theme", preferred || strstr(lower, "dark") != NULL ? "dark" : "light"};
  pudu_event(fields, 2);
}

void pudu_window_report(PuduWindow *owner) {
  GdkWindow *native = gtk_widget_get_window(owner->window);
  GdkWindowState state = native == NULL ? 0 : gdk_window_get_state(native);
  g_autofree char *id = pudu_number(owner->id);
  g_autofree char *scale = pudu_number(gtk_widget_get_scale_factor(owner->window) * 1000);
  const char *fields[] = {"window-state", id, pudu_flag(state & GDK_WINDOW_STATE_ICONIFIED),
    pudu_flag(state & GDK_WINDOW_STATE_MAXIMIZED), pudu_flag(state & GDK_WINDOW_STATE_FULLSCREEN),
    pudu_flag(gtk_widget_get_visible(owner->window)), pudu_flag(gtk_window_is_active(GTK_WINDOW(owner->window)))};
  const char *density[] = {"scale", id, scale};
  pudu_event(fields, 7);
  pudu_event(density, 3);
}

static gboolean pudu_state_changed(GtkWidget *widget, GdkEventWindowState *event, gpointer data) {
  (void)widget;
  (void)event;
  pudu_window_report(data);
  return FALSE;
}

static void pudu_scale_changed(GObject *object, GParamSpec *spec, gpointer data) {
  (void)object;
  (void)spec;
  pudu_window_report(data);
}

static void pudu_theme_changed(GObject *object, GParamSpec *spec, gpointer data) {
  (void)object;
  (void)spec;
  (void)data;
  pudu_theme();
}

static void pudu_header_visible(GtkWidget *header, gboolean visible) {
  gtk_widget_set_no_show_all(header, FALSE);
  if (visible) gtk_widget_show_all(header);
  else gtk_widget_hide(header);
  gtk_widget_set_no_show_all(header, !visible);
}

void pudu_window_title(PuduWindow *owner) {
  const char *title = gtk_window_get_title(GTK_WINDOW(owner->window));
  gtk_header_bar_set_title(GTK_HEADER_BAR(owner->titlebar), title);
  gtk_header_bar_set_title(GTK_HEADER_BAR(owner->overlaybar), title);
}

void pudu_window_hooks(PuduWindow *owner) {
  static gboolean theme_connected;
  owner->minimizable = TRUE;
  owner->maximizable = TRUE;
  owner->titlebar = gtk_header_bar_new();
  owner->overlaybar = gtk_header_bar_new();
  gtk_header_bar_set_show_close_button(GTK_HEADER_BAR(owner->titlebar), TRUE);
  gtk_header_bar_set_show_close_button(GTK_HEADER_BAR(owner->overlaybar), TRUE);
  gtk_window_set_titlebar(GTK_WINDOW(owner->window), owner->titlebar);
  gtk_widget_set_halign(owner->overlaybar, GTK_ALIGN_FILL);
  gtk_widget_set_valign(owner->overlaybar, GTK_ALIGN_START);
  gtk_overlay_add_overlay(GTK_OVERLAY(owner->overlay), owner->overlaybar);
  pudu_header_visible(owner->overlaybar, FALSE);
  pudu_window_title(owner);
  GtkCssProvider *css = gtk_css_provider_new();
  gtk_css_provider_load_from_data(css,
    ".pudu-transparent { background-color: transparent; background-image: none; box-shadow: none; border: none; }", -1, NULL);
  gtk_style_context_add_provider(gtk_widget_get_style_context(owner->titlebar), GTK_STYLE_PROVIDER(css), GTK_STYLE_PROVIDER_PRIORITY_APPLICATION);
  g_object_unref(css);

  g_signal_connect(owner->window, "window-state-event", G_CALLBACK(pudu_state_changed), owner);
  g_signal_connect(owner->window, "notify::scale-factor", G_CALLBACK(pudu_scale_changed), owner);
  if (!theme_connected) {
    GtkSettings *settings = gtk_settings_get_default();
    g_signal_connect(settings, "notify::gtk-application-prefer-dark-theme", G_CALLBACK(pudu_theme_changed), NULL);
    g_signal_connect(settings, "notify::gtk-theme-name", G_CALLBACK(pudu_theme_changed), NULL);
    theme_connected = TRUE;
  }
}

void pudu_window_geometry(PuduWindow *owner) {
  GdkGeometry hints = {.min_width = owner->min_width, .min_height = owner->min_height,
    .max_width = owner->max_width == 0 ? G_MAXINT : owner->max_width,
    .max_height = owner->max_height == 0 ? G_MAXINT : owner->max_height};
  gtk_window_set_geometry_hints(GTK_WINDOW(owner->window), NULL, &hints, GDK_HINT_MIN_SIZE | GDK_HINT_MAX_SIZE);
}

static void pudu_window_functions(PuduWindow *owner) {
  gtk_widget_realize(owner->window);
  GdkWMFunction functions = GDK_FUNC_MOVE;
  if (gtk_window_get_resizable(GTK_WINDOW(owner->window))) functions |= GDK_FUNC_RESIZE;
  if (gtk_window_get_deletable(GTK_WINDOW(owner->window))) functions |= GDK_FUNC_CLOSE;
  if (owner->minimizable) functions |= GDK_FUNC_MINIMIZE;
  if (owner->maximizable) functions |= GDK_FUNC_MAXIMIZE;
  gdk_window_set_functions(gtk_widget_get_window(owner->window), functions);
  GString *layout = g_string_new(":");
  if (owner->minimizable) g_string_append(layout, "minimize");
  if (owner->maximizable && gtk_window_get_resizable(GTK_WINDOW(owner->window))) {
    if (layout->len > 1) g_string_append_c(layout, ',');
    g_string_append(layout, "maximize");
  }
  if (gtk_window_get_deletable(GTK_WINDOW(owner->window))) {
    if (layout->len > 1) g_string_append_c(layout, ',');
    g_string_append(layout, "close");
  }
  gtk_header_bar_set_decoration_layout(GTK_HEADER_BAR(owner->titlebar), layout->str);
  gtk_header_bar_set_decoration_layout(GTK_HEADER_BAR(owner->overlaybar), layout->str);
  g_string_free(layout, TRUE);
}

static int32_t pudu_titlebar(PuduWindow *owner, pudu_field style) {
  gboolean overlay = pudu_field_is(style, "overlay");
  gboolean transparent = pudu_field_is(style, "transparent");
  if (!overlay && !transparent && !pudu_field_is(style, "visible"))
    return pudu_refuse(PUDU_WEBVIEW_MALFORMED, "titlebar needs visible, transparent or overlay");
  GtkStyleContext *context = gtk_widget_get_style_context(owner->titlebar);
  if (transparent) gtk_style_context_add_class(context, "pudu-transparent");
  else gtk_style_context_remove_class(context, "pudu-transparent");
  pudu_header_visible(owner->titlebar, !overlay);
  pudu_header_visible(owner->overlaybar, overlay);
  gtk_window_set_decorated(GTK_WINDOW(owner->window), !overlay);
  return PUDU_WEBVIEW_DONE;
}

int32_t pudu_window_extra(PuduWindow *owner, pudu_field *fields, int count) {
  pudu_field verb = fields[2];
  GtkWindow *window = GTK_WINDOW(owner->window);
  GdkWindow *native = gtk_widget_get_window(owner->window);
  gboolean maximized = native != NULL && (gdk_window_get_state(native) & GDK_WINDOW_STATE_MAXIMIZED);
  if (pudu_field_is(verb, "minimize") || pudu_field_is(verb, "unminimize") ||
      pudu_field_is(verb, "maximize") || pudu_field_is(verb, "unmaximize") || pudu_field_is(verb, "toggle-maximize")) {
    if (count != 3) return pudu_refuse(PUDU_WEBVIEW_MALFORMED, "window state action takes no values");
    if (pudu_field_is(verb, "minimize")) gtk_window_iconify(window);
    else if (pudu_field_is(verb, "unminimize")) gtk_window_deiconify(window);
    else if (pudu_field_is(verb, "unmaximize") || (pudu_field_is(verb, "toggle-maximize") && maximized)) gtk_window_unmaximize(window);
    else gtk_window_maximize(window);
  } else if (pudu_field_is(verb, "always-on-top") || pudu_field_is(verb, "decorations") ||
      pudu_field_is(verb, "closable") || pudu_field_is(verb, "minimizable") ||
      pudu_field_is(verb, "maximizable") || pudu_field_is(verb, "resizable") || pudu_field_is(verb, "content-protected")) {
    if (count != 4 || !(pudu_field_is(fields[3], "0") || pudu_field_is(fields[3], "1")))
      return pudu_refuse(PUDU_WEBVIEW_MALFORMED, "window flag needs 0 or 1");
    gboolean value = pudu_field_is(fields[3], "1");
    if (pudu_field_is(verb, "always-on-top")) gtk_window_set_keep_above(window, value);
    else if (pudu_field_is(verb, "decorations")) gtk_window_set_decorated(window, value);
    else if (pudu_field_is(verb, "closable")) gtk_window_set_deletable(window, value);
    else if (pudu_field_is(verb, "minimizable")) owner->minimizable = value;
    else if (pudu_field_is(verb, "maximizable")) owner->maximizable = value;
    else if (pudu_field_is(verb, "resizable")) gtk_window_set_resizable(window, value);
    else return pudu_refuse(PUDU_WEBVIEW_UNSUPPORTED, "capture protection is not provided by this desktop protocol");
    pudu_window_functions(owner);
  } else if (pudu_field_is(verb, "background") && count == 7) {
    int64_t channels[4];
    for (int i = 0; i < 4; i++)
      if (pudu_field_int(fields[i + 3], &channels[i]) != 0 || channels[i] < 0 || channels[i] > 255)
        return pudu_refuse(PUDU_WEBVIEW_MALFORMED, "background needs four channels in 0..255");
    char alpha[G_ASCII_DTOSTR_BUF_SIZE];
    g_ascii_dtostr(alpha, sizeof alpha, channels[3] / 255.0);
    g_autofree char *css = g_strdup_printf("window { background-color: rgba(%lld,%lld,%lld,%s); }",
      (long long)channels[0], (long long)channels[1], (long long)channels[2], alpha);
    GtkStyleContext *context = gtk_widget_get_style_context(owner->window);
    if (owner->background_css != NULL) {
      gtk_style_context_remove_provider(context, GTK_STYLE_PROVIDER(owner->background_css));
      g_object_unref(owner->background_css);
    }
    owner->background_css = gtk_css_provider_new();
    gtk_css_provider_load_from_data(owner->background_css, css, -1, NULL);
    gtk_style_context_add_provider(context, GTK_STYLE_PROVIDER(owner->background_css), GTK_STYLE_PROVIDER_PRIORITY_APPLICATION);
  } else if (pudu_field_is(verb, "titlebar") && count == 4) {
    int32_t status = pudu_titlebar(owner, fields[3]);
    if (status != PUDU_WEBVIEW_DONE) return status;
  } else if (pudu_field_is(verb, "attention") && count == 4) {
    if (!(pudu_field_is(fields[3], "critical") || pudu_field_is(fields[3], "informational")))
      return pudu_refuse(PUDU_WEBVIEW_MALFORMED, "attention needs critical or informational");
    gtk_window_set_urgency_hint(window, TRUE);
  } else if (pudu_field_is(verb, "badge") && count == 4) {
    return pudu_refuse(PUDU_WEBVIEW_UNSUPPORTED, "application badges require a desktop-specific integration");
  } else if (pudu_field_is(verb, "state") && count == 3) {
    int x, y, width, height;
    gtk_window_get_position(window, &x, &y);
    gtk_window_get_size(window, &width, &height);
    g_autofree char *id = pudu_number(owner->id);
    g_autofree char *sx = pudu_number(x), *sy = pudu_number(y);
    g_autofree char *sw = pudu_number(width), *sh = pudu_number(height);
    const char *moved[] = {"moved", id, sx, sy};
    const char *resized[] = {"resized", id, sw, sh};
    pudu_event(moved, 4);
    pudu_event(resized, 4);
    pudu_theme();
  } else return pudu_refuse(PUDU_WEBVIEW_MALFORMED, "unknown or malformed window action");
  pudu_window_report(owner);
  return PUDU_WEBVIEW_DONE;
}
